module Pricing
  class Order
    include AggregateRoot

    def initialize(id)
      @id = id
      @product_quantity_hash = Hash.new(0)
      @discount = Discounts::NoPercentageDiscount.new
    end

    def add_item(product_id)
      apply PriceItemAdded.new(
        data: {
          order_id: @id,
          product_id: product_id
        }
      )
    end

    def remove_item(product_id)
      apply PriceItemRemoved.new(
        data: {
          order_id: @id,
          product_id: product_id
        }
      )
    end

    def apply_discount(discount)
      raise NotPossibleToAssignDiscountTwice if @discount.value.nonzero?
      apply PercentageDiscountSet.new(
        data: {
          order_id: @id,
          amount: discount.value
        }
      )
    end

    def change_discount(discount)
      raise NotPossibleToChangeDiscount if @discount.value.zero?
      apply PercentageDiscountChanged.new(
        data: {
          order_id: @id,
          amount: discount.value
        }
      )
    end

    def reset_discount
      raise NotPossibleToResetWithoutDiscount if @discount.value.zero?
      apply PercentageDiscountReset.new(
        data: {
          order_id: @id
        }
      )
    end

    def make_product_free(order_id, product_id)
      raise FreeProductAlreadyMade if @product_quantity_hash.keys.any? {|key| key.instance_of?(FreeProduct)}
      apply ProductMadeFreeForOrder.new(
        data: {
          order_id: order_id,
          product_id: product_id
        }
      )
    end

    def remove_free_product(order_id, product_id)
      raise FreeProductNotExists if @product_quantity_hash.keys.none? {|key| key.instance_of?(FreeProduct)}
      apply FreeProductRemovedFromOrder.new(
        data: {
          order_id: order_id,
          product_id: product_id
        }
      )
    end

    def calculate_total_value(pricing_catalog, time_promotion_discount)
      total_value = @product_quantity_hash.sum { |product, qty| pricing_catalog.price_for(product) * qty }

      discounted_value = @discount.add(time_promotion_discount).apply(total_value)
      apply(
        OrderTotalValueCalculated.new(
          data: {
            order_id: @id,
            total_amount: total_value,
            discounted_amount: discounted_value
          }
        )
      )
    end

    def calculate_sub_amounts(pricing_catalog, time_promotions_discount)
      sub_amounts_total = @product_quantity_hash.map do |product, quantity|
        quantity * pricing_catalog.price_for(product)
      end
      sub_discounts = calculate_total_sub_discounts(pricing_catalog, time_promotions_discount)

      products = @product_quantity_hash.keys
      quantities = @product_quantity_hash.values
      products.zip(quantities, sub_amounts_total, sub_discounts) do |product, quantity, sub_amount, sub_discount|
        apply(
          PriceItemValueCalculated.new(
            data: {
              order_id: @id,
              product_id: product.id,
              quantity: quantity,
              amount: sub_amount,
              discounted_amount: sub_amount - sub_discount
            }
          )
        )
      end
    end

    private

    on PriceItemAdded do |event|
      @product_quantity_hash[Product.new(event.data.fetch(:product_id))] += 1
    end

    on PriceItemRemoved do |event|
      if @product_quantity_hash[Product.new(event.data.fetch(:product_id))]
        @product_quantity_hash[Product.new(event.data.fetch(:product_id))] -= 1
      else
        @product_quantity_hash[FreeProduct.new(event.data.fetch(:product_id))] -= 1
      end
      clear_empty_products
    end

    def clear_empty_products
      @product_quantity_hash.delete_if { |_, value| value.zero? }
    end

    on PriceItemValueCalculated do |event|
    end

    on OrderTotalValueCalculated do |event|
    end

    on PercentageDiscountSet do |event|
      @discount = Discounts::PercentageDiscount.new(event.data.fetch(:amount))
    end

    on PercentageDiscountChanged do |event|
      @discount = Discounts::PercentageDiscount.new(event.data.fetch(:amount))
    end

    on PercentageDiscountReset do |event|
      @discount = Discounts::NoPercentageDiscount.new
    end

    on ProductMadeFreeForOrder do |event|
      replace(Product, FreeProduct, event.data.fetch(:product_id))
      clear_empty_products
    end

    on FreeProductRemovedFromOrder do |event|
      replace(FreeProduct, Product, event.data.fetch(:product_id))
      clear_empty_products
    end

    def calculate_total_sub_discounts(pricing_catalog, time_promotions_discount)
      @product_quantity_hash.map do |product, quantity|
        catalog_price_for_single = pricing_catalog.price_for(product)
        with_total_discount_single = @discount.add(time_promotions_discount).apply(catalog_price_for_single)
        quantity * (catalog_price_for_single - with_total_discount_single)
      end
    end

    def replace(from, to, product_id)
      @product_quantity_hash[from.new(product_id)] -= 1
      @product_quantity_hash[to.new(product_id)] += 1
    end

    class Product
      attr_reader :id

      def initialize(id)
        @id = id
      end

      def eql?(other)
        other.instance_of?(Product) && id.eql?(other.id)
      end

      alias == eql?

      def hash
        Product.hash ^ id.hash
      end
    end

    class FreeProduct
      attr_reader :id

      def initialize(id)
        @id = id
      end

      def eql?(other)
        other.instance_of?(FreeProduct) && id.eql?(other.id)
      end

      alias == eql?

      def hash
        FreeProduct.hash ^ id.hash
      end
    end
  end
end
