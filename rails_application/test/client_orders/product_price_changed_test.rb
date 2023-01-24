require "test_helper"

module ClientOrders
  class ProductPriceChangedTest < InMemoryTestCase
    cover "ClientOrders*"

    def test_reflects_change
      product_id = prepare_product
      unchanged_product_id = prepare_product

      run_command(Pricing::SetPrice.new(product_id: product_id, price: 100))

      assert_equal 100, Product.find_by_uid(product_id).price
      assert_equal 50, Product.find_by_uid(unchanged_product_id).price
    end

    def test_registers_lowest_recent_price
      product_id = prepare_product

      run_command(Pricing::SetPrice.new(product_id: product_id, price: 40))

      assert_equal 40, Product.find_by_uid(product_id).lowest_recent_price
    end

    def test_keeps_lowest_recent_price
      product_id = prepare_product

      run_command(Pricing::SetPrice.new(product_id: product_id, price: 100))
      run_command(Pricing::SetPrice.new(product_id: product_id, price: 20))
      run_command(Pricing::SetPrice.new(product_id: product_id, price: 50))
      run_command(Pricing::SetPrice.new(product_id: product_id, price: 70))

      assert_equal 20, Product.find_by_uid(product_id).lowest_recent_price
    end

    def prepare_product
      product_id = SecureRandom.uuid
      run_command(
        ProductCatalog::RegisterProduct.new(
          product_id: product_id,
          )
      )
      run_command(
        ProductCatalog::NameProduct.new(
          product_id: product_id,
          name: "test"
        )
      )
      run_command(Pricing::SetPrice.new(product_id: product_id, price: 50))

      product_id
    end
  end
end
