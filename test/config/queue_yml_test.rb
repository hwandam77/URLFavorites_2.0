# frozen_string_literal: true

require "test_helper"

class QueueYmlTest < ActiveSupport::TestCase
  test "SolidQueue workers use array queues (not comma strings)" do
    config = SolidQueue::Configuration.new
    workers = config.send(:workers_options)

    assert workers.size >= 2
    workers.each do |worker|
      assert_kind_of Array, worker[:queues], "queues must be Array, got #{worker[:queues].inspect}"
    end

    assert_equal %w[default search mailers reindex], workers[0][:queues]
    assert_equal %w[ai ai_refine], workers[1][:queues]
  end
end
