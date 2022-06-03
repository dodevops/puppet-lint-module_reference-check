# frozen_string_literal: true

require_relative 'reference_workflow'

REF_TYPE_ENUM = {
  internal: 0,
  component: 1,
  feature: 2
}.freeze

INTERNAL_MODULE_REGEXP = /^(role|profile)::/.freeze

# Comment received in an invalid state
class InvalidTokenForState < StandardError
  def initialize(token, state)
    @token = token
    @state = state
    super "Can not process the token '#{@token.value.strip}' in the state #{@state}"
  end

  attr_reader :token
end

# A utility class to process tokens and analyze includes
class Reference
  def initialize
    @workflow = ReferenceWorkflow.new(self)

    reset
  end

  def reset
    @current_token = nil
    @references = []
  end

  def get_body_start(tokens)
    params_started = false
    params_ended = false
    params_brackets = 0
    tokens.each_with_index do |token, index|
      params_started = true if token.type == :LPAREN && !params_started
      params_brackets += 1 if token.type == :LPAREN && params_started
      params_brackets -= 1 if token.type == :RPAREN && params_started
      params_ended = true if params_started && params_brackets.zero?
      return index + 1 if params_ended && token.type == :LBRACE
    end
    warn('No class or type body found')
  end

  def process(tokens)
    tokens = tokens.drop(get_body_start(tokens))
    feature_includes = []
    tokens.reject { |token| %i[WHITESPACE NEWLINE INDENT].include? token.type }.each do |token|
      @current_token = token
      @workflow.got_include if token.value == 'include'
      @workflow.got_class if token.value == 'class'
      @workflow.got_features_start if token.value == 'role::include_features'
      @workflow.got_feature if token.type == :LBRACK && @workflow.current == :awaiting_feature
      @workflow.got_feature_end if token.type == :RBRACK && @workflow.current == :awaiting_feature_include
      @workflow.got_features_end(feature_includes) if token.type == :RBRACE && @workflow.current == :got_feature_start
      next unless %i[NAME SSTRING].include?(token.type)
      next if %w[include class role::include_features].include?(token.value)

      # noinspection RubyCaseWithoutElseBlockInspection
      case @workflow.current
      when :awaiting_include_name
        @workflow.got_include_name(token.value)
      when :awaiting_class_name
        @workflow.got_class_name(token.value)
      when :awaiting_feature_include
        feature_includes.append(token.value)
      end
    end
  end

  def got_include_name_trigger(include_name)
    @references.append(
      {
        type: include_name.match(INTERNAL_MODULE_REGEXP) ? REF_TYPE_ENUM[:internal] : REF_TYPE_ENUM[:component],
        name: include_name,
        token: @current_token
      }
    )
  end

  def got_class_name_trigger(class_name)
    @references.append(
      {
        type: class_name.match(INTERNAL_MODULE_REGEXP) ? REF_TYPE_ENUM[:internal] : REF_TYPE_ENUM[:component],
        name: class_name,
        token: @current_token
      }
    )
  end

  def got_features_end_trigger(feature_includes)
    feature_includes.each do |include_name|
      @references.append(
        {
          type: REF_TYPE_ENUM[:feature],
          name: include_name,
          token: @current_token
        }
      )
    end
  end

  def invalid_state
    raise InvalidTokenForState.new @current_token, @workflow.current
  end

  attr_reader :references
end
