# frozen_string_literal: true

require_relative '../../spec_helper'

describe 'module_reference' do
  context 'valid code' do
    let(:code) do
      <<~CODE
        # @ref apache
        # @note puppetlabs-apache
        # @see https://forge.puppet.com/modules/puppetlabs/apache
        #
        # @see profile::test
        #
        # @see profile::testfeature - Feature "test"
        class test () {
          include profile::test
          class {
            'apache':
          }
          include apache

          role::include_features({
            'testfeature' => [
              profile::testfeature,
            ],
          })
        }
      CODE
    end

    it 'should not detect any problems' do
      expect(problems).to have(0).problems
    end
  end

  context 'code with missing internal link' do
    let(:code) do
      <<~CODE
        class test () {
          include profile::test
        }
      CODE
    end

    it 'should detect exactly one problem' do
      expect(problems).to have(1).problems
    end

    it 'should create a warning' do
      expect(problems).to contain_warning('Module profile::test not referenced in the comments').on_line(2).in_column(11)
    end
  end

  context 'code with missing component link' do
    let(:code) do
      <<~CODE
        class test () {
          class {
            'apache':
          }
        }
      CODE
    end

    it 'should detect exactly one problem' do
      expect(problems).to have(1).problems
    end

    it 'should create a warning' do
      expect(problems).to contain_warning('Can\'t find @ref tag for reference apache').on_line(1).in_column(1)
    end
  end
end