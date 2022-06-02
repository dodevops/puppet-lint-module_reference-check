# frozen_string_literal: true

require 'finite_machine'

# A workflow to describe includes and class declarations
class IncludeWorkflow < FiniteMachine::Definition
  initial :start

  event :got_include, from: :start, to: :awaiting_include_name
  event :got_include_name, from: :awaiting_include_name, to: :start

  event :got_class, from: :start, to: :awaiting_class_name
  event :got_class_name, from: :awaiting_class_name, to: :start

  event :got_features_start, from: :start, to: :awaiting_feature
  event :got_feature, from: :awaiting_feature, to: :awaiting_feature_include
  event :got_feature_end, from: :awaiting_feature_include, to: :got_feature_start
  event :got_features_end, from: :got_feature_start, to: :start

  on_before(:got_include_name) { |_, include_name| target.got_include_name_trigger(include_name) }
  on_before(:got_class_name) { |_, class_name| target.got_class_name_trigger(class_name) }
  on_before(:got_features_end) { |_, feature_includes| target.got_features_end_trigger(feature_includes) }

  handle FiniteMachine::InvalidStateError, with: -> { target.invalid_state }
end
