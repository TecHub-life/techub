module Ahoy
  class Event < ApplicationRecord
    self.table_name = "ahoy_events"
    belongs_to :visit, optional: true, class_name: "Ahoy::Visit", foreign_key: :visit_id
    belongs_to :user, optional: true
  end
end
