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

  context 'valid code with reference to unused module' do
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
        }
      CODE
    end

    it 'should detect detect any problems' do
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

  context 'code with wrong component @see' do
    let(:code) do
      <<~CODE
        # @ref apache
        # @note puppetlabs-apache
        # @see https://example.com
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
      expect(problems).to contain_warning('First @see for reference apache is not the Puppet forge').on_line(1).in_column(1)
    end
  end

  context 'code with internal references sorted before component references' do
    let(:code) do
      <<~CODE
        # @see profile::test
        #
        # @ref apache
        # @note puppetlabs-apache
        # @see https://forge.puppet.com/modules/puppetlabs/apache
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

    it 'should detect exactly one problem' do
      expect(problems).to have(1).problems
    end

    it 'should create a warning' do
      expect(problems).to contain_warning('Reference to profile::test was found higher than @see https://forge.puppet.com/modules/puppetlabs/apache').on_line(1).in_column(1)
    end
  end

  context 'code with feature references sorted before internal references' do
    let(:code) do
      <<~CODE
        # @ref apache
        # @note puppetlabs-apache
        # @see https://forge.puppet.com/modules/puppetlabs/apache
        #
        # @see profile::testfeature - Feature "test"
        #
        # @see profile::test
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

    it 'should detect exactly one problem' do
      expect(problems).to have(1).problems
    end

    it 'should create a warning' do
      expect(problems).to contain_warning('Reference to profile::testfeature was found higher than @see profile::test').on_line(1).in_column(1)
    end
  end

  context 'code with unsorted component references' do
    let(:code) do
      <<~CODE
        # @ref postgresql
        # @note puppetlabs-postgresql
        # @see https://forge.puppet.com/modules/puppetlabs/postgresql
        #
        # @ref apache
        # @note puppetlabs-apache
        # @see https://forge.puppet.com/modules/puppetlabs/apache
        class test () {
          class {
            'apache':
          }
          include postgresql
        }
      CODE
    end

    it 'should detect exactly one problem' do
      expect(problems).to have(1).problems
    end

    it 'should create a warning' do
      expect(problems).to contain_warning('puppetlabs-apache sorted after puppetlabs-postgresql').on_line(1).in_column(1)
    end
  end

  context 'code with unsorted internal references' do
    let(:code) do
      <<~CODE
        # @see profile::b
        # @see profile::a
        class test () {
          include profile::a
          include profile::b
        }
      CODE
    end

    it 'should detect exactly one problem' do
      expect(problems).to have(1).problems
    end

    it 'should create a warning' do
      expect(problems).to contain_warning('profile::a sorted after profile::b').on_line(1).in_column(1)
    end
  end

  context 'code with unsorted feature references' do
    let(:code) do
      <<~CODE
        # @see profile::b
        # @see profile::a
        class test () {
          role::include_features({
            'testfeature' => [
              profile::a,
              profile::b
            ],
          })
        }
      CODE
    end

    it 'should detect exactly one problem' do
      expect(problems).to have(1).problems
    end

    it 'should create a warning' do
      expect(problems).to contain_warning('profile::a sorted after profile::b').on_line(1).in_column(1)
    end
  end
end
