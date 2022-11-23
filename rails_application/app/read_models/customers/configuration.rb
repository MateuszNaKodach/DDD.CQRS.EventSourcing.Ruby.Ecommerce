module Customers
  class Customer < ApplicationRecord
    self.table_name = "customers"
  end

  class Configuration

    def call(event_store)
      event_store.subscribe(RegisterCustomer, to: [Crm::CustomerRegistered])

      event_store.subscribe(
          -> (event) { promote_to_vip(event) },
          to: [Crm::CustomerPromotedToVip]
      )
    end

    private

    def register_customer(event)
      Customer.create(id: event.data.fetch(:customer_id), name: event.data.fetch(:name))
    end

    def promote_to_vip(event)
      find(event.data.fetch(:customer_id)).update(vip: true)
    end

    def find(customer_id)
      Customer.where(id: customer_id).first
    end
  end
end
