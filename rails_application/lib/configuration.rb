require 'cqrs'
require 'command_handler'
require 'command'
require 'event'
require 'types'

require Rails.root.join("../ecommerce/ordering/lib/ordering/configuration")
require Rails.root.join("../ecommerce/pricing/lib/pricing")
require Rails.root.join("../ecommerce/product_catalog/lib/product_catalog")
require Rails.root.join("../ecommerce/crm/lib/crm")
require Rails.root.join("../ecommerce/payments/lib/payments")

class Configuration
  def call(event_store, command_bus)
    event_store.subscribe_to_all_events(RailsEventStore::LinkByEventType.new)
    event_store.subscribe_to_all_events(RailsEventStore::LinkByCorrelationId.new)
    event_store.subscribe_to_all_events(RailsEventStore::LinkByCausationId.new)

    cqrs = Cqrs.new(event_store, command_bus)

    Orders::Configuration.new(cqrs).call
    Ordering::Configuration.new(cqrs).call
    Pricing::Configuration.new(cqrs).call
    Payments::Configuration.new(cqrs).call
    ProductCatalog::Configuration.new(cqrs).call
    Crm::Configuration.new(cqrs).call

    cqrs.subscribe(PaymentProcess.new, [
      Ordering::OrderSubmitted,
      Ordering::OrderExpired,
      Ordering::OrderPaid,
      Payments::PaymentAuthorized,
      Payments::PaymentReleased,
    ])

    cqrs.subscribe(OrderConfirmation.new, [
      Payments::PaymentAuthorized,
      Payments::PaymentCaptured
    ])

    cqrs.subscribe(ProductCatalog::AssignPriceToProduct.new, [Pricing::PriceSet])

    cqrs.subscribe(
      -> (event) { cqrs.run(Pricing::CalculateTotalValue.new(order_id: event.data.fetch(:order_id)))},
      [Ordering::OrderSubmitted])

    cqrs.subscribe(
      -> (event) { cqrs.run(
        Payments::SetPaymentAmount.new(order_id: event.data.fetch(:order_id), amount: event.data.fetch(:discounted_amount).to_f))},
      [Pricing::OrderTotalValueCalculated])
  end
end
