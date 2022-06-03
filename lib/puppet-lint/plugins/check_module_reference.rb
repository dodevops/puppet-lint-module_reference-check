# frozen_string_literal: true

require_relative '../../puppet-lint-module_reference-check/reference'

# Find the header comments for a class or a defined type
#
# @param tokens The list of all tokens
# @param token_start The index of the token to start from upwards
# @return The head comments
def get_comments(tokens, token_start)
  comments = []
  token_pointer = token_start - 1
  while token_pointer >= 0
    break unless %i[COMMENT NEWLINE].include? tokens[token_pointer].type

    comments.append(tokens[token_pointer])
    token_pointer -= 1
  end
  comments.reject { |comment| comment.type == :NEWLINE }.reverse!
end

def get_first_index_of_type(comments, type, feature_refs)
  comments.each_with_index do |comment, index|
    comment.match(/@see (?<name>\S+)/) do |match|
      next if feature_refs.any? { |ref| ref[:name] == match.named_captures['name'] }
      return index if match.named_captures['name'].match?(INTERNAL_MODULE_REGEXP) && type == REF_TYPE_ENUM[:internal]
      return index if !match.named_captures['name'].match?(INTERNAL_MODULE_REGEXP) && type == REF_TYPE_ENUM[:component]
    end
  end
  0
end

PuppetLint.new_check(:module_reference) do
  def initialize
    @workflow = Reference.new
    # noinspection RubySuperCallWithoutSuperclassInspection
    super
  end

  def warn(message, line = 1, column = 1)
    notify :warning, { message: message, line: line, column: column }
    false
  end

  def check_sees_exist(references, comments)
    references.each do |reference|
      next if comments.any? { |comment| comment.match?("^@see #{reference[:name]}\\s?") }

      return warn(
        "Module #{reference[:name]} not referenced in the comments",
        reference[:token].line,
        reference[:token].column
      )
    end
    true
  end

  def check_reference_order(references, comments, below_index)
    references.each do |reference|
      if comments.find_index { |comment| comment.match?("^@see #{reference[:name]}\\s?") } < below_index
        return warn("Reference to #{reference[:name]} was found higher than #{comments[below_index]}")
      end
    end
    true
  end

  def check_internal_references(comments)
    internal_references = @workflow.references.filter { |ref| ref[:type] == REF_TYPE_ENUM[:internal] }
    return false unless check_sees_exist(internal_references, comments)
    return false unless check_reference_order(
      internal_references,
      comments,
      get_first_index_of_type(
        comments,
        REF_TYPE_ENUM[:component],
        @workflow.references.filter { |ref| ref[:type] == REF_TYPE_ENUM[:feature] }
      )
    )

    true
  end

  def find_ref_index(name, comments)
    comments.each_with_index do |comment, index|
      comment.match(/^@ref (?<ref_regexps>.+)\s?/) do |match|
        match.named_captures['ref_regexps'].split(',').each do |ref_regexp|
          return index if name.match?(ref_regexp)
        end
      end
    end
    nil
  end

  def check_component_references(comments)
    component_refs = @workflow.references.filter { |ref| ref[:type] == REF_TYPE_ENUM[:component] }
    component_refs.each do |reference|
      ref_index = find_ref_index(reference[:name], comments)
      return warn("Can't find @ref tag for reference #{reference[:name]}") if ref_index.nil?
      return warn("Missing @note tag for reference #{reference[:name]}") unless comments[ref_index + 1].match?(/@note/)
      return warn("Missing @see tag for reference #{reference[:name]}") unless comments[ref_index + 2].match?(/@see/)
      next if comments[ref_index + 2].include?('https://forge.puppet.com/')

      return warn("First @see for reference #{reference[:name]} is not the Puppet forge")
    end
    true
  end

  def check_feature_references(comments)
    feature_refs = @workflow.references.filter { |ref| ref[:type] == REF_TYPE_ENUM[:feature] }
    return false unless check_sees_exist(feature_refs, comments)
    return false unless check_reference_order(
      feature_refs,
      comments,
      get_first_index_of_type(
        comments,
        REF_TYPE_ENUM[:internal],
        @workflow.references.filter { |ref| ref[:type] == REF_TYPE_ENUM[:feature] }
      )
    )

    true
  end

  def get_relevant_name(captures, comments, index)
    return_object = {
      name: captures['name'],
      type: nil
    }
    if captures['type'] == 'see' && (index == 0 || index > 0 && !comments[index - 1].match(/@note/))
      return return_object if captures['name'].match?(%r(https?://))

      reference = @workflow.references.select { |ref| ref[:name] == captures['name'] }
      return return_object if reference.empty?

      return_object[:type] = reference.first[:type]
    else
      @workflow
        .references
        .select { |ref| ref[:type] == REF_TYPE_ENUM[:component] }
        .each do |ref|
        next unless captures['name'].split(',').any? { |refmatch| ref[:name].match?(refmatch) }

        comments[index + 1].match(/^@note (?<name>.+)$/) do |matchdata|
          return_object[:name] = matchdata['name']
          return_object[:type] = ref[:type]
          break
        end
      end
    end
    return_object
  end

  def check_order(comments)
    last_comment = nil
    current_type = REF_TYPE_ENUM[:component]
    comments.each_with_index do |comment, index|
      comment.match(/@(?<type>see|ref) (?<name>\S+)/) do |match|
        ref_object = get_relevant_name(match.named_captures, comments, index)
        return false unless ref_object

        current_comment = ref_object[:name]
        return warn("No relevant name found for #{comment}") if current_comment.nil?
        next if current_comment.match?('https?://')

        if ref_object[:type] != current_type
          last_comment = nil
          current_type = ref_object[:type]
        end
        last_comment = current_comment if last_comment.nil?
        return warn("#{current_comment} sorted after #{last_comment}") if last_comment > current_comment
      end
    end
  end

  # Check class or defined type indexes
  def check_indexes(indexes)
    indexes.each do |index|
      comments = get_comments(tokens, index[:start] - 1)
                 .map { |comment| comment.value.strip }
                 .filter { |comment| comment.match?(/^@(see|note|ref)/) }
      begin
        @workflow.process(tokens[index[:start], index[:end]])
      rescue InvalidTokenForState => e
        warn(e.message, e.token.line, e.token.column)
      end
      return false unless check_internal_references(comments)
      return false unless check_component_references(comments)
      return false unless check_feature_references(comments)
      return false unless check_order(comments)
    end
    true
  end

  # Run the check
  def check
    return unless check_indexes(class_indexes)
    return unless check_indexes(defined_type_indexes)
  end
end
