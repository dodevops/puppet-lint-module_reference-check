# frozen_string_literal: true

require 'simplecov'
SimpleCov.add_filter 'vendor'
SimpleCov.start

require 'puppet-lint'

PuppetLint::Plugins.load_spec_helper
