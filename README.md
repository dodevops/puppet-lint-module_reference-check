# Puppet lint module reference check

This checks whether used modules are properly referenced in the comments by these rules:

- All internal prefixed with profile:: or role:: based on the Puppet role/profile concept) modules have to be 
  referenced using a @see tag
- All component modules have to be referenced like the following
  - All used classes and defined types need to be gathered in a comma-separated list of regexps in a @ref tag
  - The full module name (vendor-module) has to be referenced in a @note tag
  - At minimum one @see tag with a reference to the puppet forge page of the component module
  - Example:
    ```
    # @ref apache.*,a2mod
    # @note puppetlabs-apache
    # @see https://forge.puppet.com/modules/puppetlabs/apache
    ```
- Modules referenced by features (using our own role::include_features function) have to be referenced with @see
- The module references have to be sorted alphabetically and grouped by this:
  - component module
  - internal modules
  - modules referenced by features

## Usage

To use the plugin, add the following line to the Gemfile:

    gem 'puppet-lint-module_reference-check'
