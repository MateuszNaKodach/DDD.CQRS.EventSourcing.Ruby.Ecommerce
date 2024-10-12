require "test_helper"

module HeroesOnEcommerce
  module CreatureRecruitment
    # commands
    BuildCreaturesDwelling = ProductCatalog::RegisterProduct
    IncreaseAvailableCreatures = Inventory::Supply

    # events
    CreatureRecruited = Ordering::OrderPlaced
  end
end

module HeroesOnEcommerce
  module CreatureRecruitment
    class CreatureRecruitmentTest < RealRESIntegrationTestCase
      def setup
        super
        @dwelling_id = SecureRandom.uuid
        @creature_id = SecureRandom.uuid
        @creature_name = "angel"
        @cost = 3000
      end

      def test_creature_recruitment
        # when
        build_dwelling(@dwelling_id, @creature_id, @creature_name, @cost)
        increase_available_creatures(@dwelling_id, @creature_id, 2)
        recruitment_id = recruit_creature(@dwelling_id, @creature_id, 1)

        # then
        assert_creature_recruited(recruitment_id, @dwelling_id, @creature_id, 1)
      end

      # todo: we can have many dwellings (merchants?) for same creature (product)
      # it doesn't have so much sens to do such mapping, because the granularity of events may be different, IMO only synchronization is appropriate
      def build_dwelling(dwelling_id, creature_id, name, cost)
        run_command(
          CreatureRecruitment::BuildCreaturesDwelling.new(
            product_id: creature_id,
          )
        )
        run_command(
          ProductCatalog::NameProduct.new(
            product_id: creature_id,
            name: name
          )
        )
        run_command(Pricing::SetPrice.new(product_id: creature_id, price: cost))
      end

      def increase_available_creatures(dwelling_id, creature_id, increase_by)
        run_command(Recruitment::IncreaseAvailableCreatures.new(product_id: creature_id, quantity: increase_by))
      end

      def recruit_creature(dwelling_id, creature_id, quantity)
        recruitment_id = SecureRandom.uuid
        run_command(Ordering::AddItemToBasket.new(order_id: recruitment_id, product_id: creature_id, quantity: quantity))
        run_command(Ordering::SubmitOrder.new(order_id: recruitment_id))
        recruitment_id
      end

      def assert_creature_recruited(recruitment_id, dwelling_id, creature_id, quantity)
        stream_name = "Ordering::Order$#{recruitment_id}"
        assert_events_contain(
          stream_name,
          Ordering::OrderSubmitted.new(
            data: {
              order_id: recruitment_id,
              product_id: creature_id,
              order_number: "2019/01/60"
            }
          )
        )
      end

      def event_store
        Rails.configuration.event_store
      end

      def assert_events_contain(stream_name, *expected_events)
        scope = event_store.read.stream(stream_name)
        before = scope.last
        actual_events =
          before.nil? ? scope.to_a : scope.from(before.event_id).to_a
        to_compare = ->(ev) { { type: ev.event_type, data: ev.data } }
        expected_events.map(&to_compare).each do |expected|
          assert_includes(actual_events.map(&to_compare), expected)
        end
      end

    end
  end
end