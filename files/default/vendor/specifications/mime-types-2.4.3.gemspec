# -*- encoding: utf-8 -*-
# stub: mime-types 2.4.3 ruby lib

Gem::Specification.new do |s|
  s.name = "mime-types"
  s.version = "2.4.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Austin Ziegler"]
  s.cert_chain = ["-----BEGIN CERTIFICATE-----\nMIIDNjCCAh6gAwIBAgIBATANBgkqhkiG9w0BAQUFADBBMQ8wDQYDVQQDDAZhdXN0\naW4xGTAXBgoJkiaJk/IsZAEZFglydWJ5Zm9yZ2UxEzARBgoJkiaJk/IsZAEZFgNv\ncmcwHhcNMTQwMjIyMDM0MTQzWhcNMTUwMjIyMDM0MTQzWjBBMQ8wDQYDVQQDDAZh\ndXN0aW4xGTAXBgoJkiaJk/IsZAEZFglydWJ5Zm9yZ2UxEzARBgoJkiaJk/IsZAEZ\nFgNvcmcwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC2mPNf4L37GhKI\nSPCYsvYWXA2/R9u5+pyUnbJ2R1o2CiRq2ZA/AIzY6N3hGnsgoWnh5RzvgTN1Lt08\nDNIrsIG2VDYk/JVt6f9J6zZ8EQHbznWa3cWYoCFaaICdk7jV1n/42hg70jEDYXl9\ngDOl0k6JmyF/rtfFu/OIkFGWeFYIuFHvRuLyUbw66+QDTOzKb3t8o55Ihgy1GVwT\ni6pkDs8LhZWXdOD+921l2Z1NZGZa9KNbJIg6vtgYKU98jQ5qr9iY3ikBAspHrFas\nK6USvGgAg8fCD5YiotBEvCBMYtfqmfrhpdU2p+gvTgeLW1Kaevwqd7ngQmFUrFG1\neUJSURv5AgMBAAGjOTA3MAkGA1UdEwQCMAAwCwYDVR0PBAQDAgSwMB0GA1UdDgQW\nBBQLSSjKemGDapYEd/U4mS1qry2oEjANBgkqhkiG9w0BAQUFAAOCAQEANm2agTdD\n9S2NwXMW0jansInXtQmB44qk/psWujtGnn+oT+a9KXO5p/gx2mmx8hMF02wUBx1H\nk96HUI/jR3HdhYCfG6oJuEzgXrFiSBJw/cOJiM8v3aHsAwI3NeLeIrRwBYB3kI3j\n1qfJXcOWw7c63TrsDX37xj2e4P0DNJ1cTrDmyD2yTQ5776M13Gb6nXjreSeq0t/n\n60Nj91J1oHYk6LFa0eo/gykTbLyaZrsaXlNb3j7CjhUzOpYOhiCUH3s9tKTGXd/+\nLmZ7BxTMsDhZHy3k/ETFhi+7pIUWlFo0imrdyLhd+Jw3boVj3CmvyhcwmpoM0K9l\nAOmrUiElUqLOZA==\n-----END CERTIFICATE-----\n"]
  s.date = "2014-10-21"
  s.description = "The mime-types library provides a library and registry for information about\nMIME content type definitions. It can be used to determine defined filename\nextensions for MIME types, or to use filename extensions to look up the likely\nMIME type definitions.\n\nMIME content types are used in MIME-compliant communications, as in e-mail or\nHTTP traffic, to indicate the type of content which is transmitted. The\nmime-types library provides the ability for detailed information about MIME\nentities (provided as an enumerable collection of MIME::Type objects) to be\ndetermined and used programmatically. There are many types defined by RFCs and\nvendors, so the list is long but by definition incomplete; don't hesitate to to\nadd additional type definitions (see Contributing.rdoc). The primary sources\nfor MIME type definitions found in mime-types is the IANA collection of\nregistrations (see below for the link), RFCs, and W3C recommendations.\n\nThis is release 2.4.3, restoring full compatibility with Ruby 1.9.2 (which will\nbe dropped in mime-types 3.0). It also includes the performance improvements\nfrom mime-types 2.4.2 (since yanked because of the broken Ruby 1.9.2 support)\nand the 2.4.1 fix of a bug in observed use of the mime-types library where\nextensions were not previously sorted, such that\n\n    MIME::Types.of('image.jpg').first.extensions.first\n\nreturned a value of +jpeg+ in mime-types 1, but +jpe+ in mime-types 2. This was\nintroduced because extensions were sorted during assignment\n(MIME::Type#extensions=). This behaviour has been reverted to protect clients\nthat work as noted above. The preferred way to express this is the new method:\n\n    MIME::Type.of('image.jpg').first.preferred_extension\n\n\u{141}ukasz \u{15a}liwa created the\n{friendly_mime}[https://github.com/lukaszsliwa/friendly_mime] gem, which offers\nfriendly descriptive names for MIME types. This functionality and\nEnglish-language data has been added to mime-types as MIME::Type#friendly. To\nmake it easy for internationalization, MIME::Type#i18n_key has been added,\nwhich will return a key suitable for use with the\n{I18n}[https://github.com/svenfuchs/i18n] library.\n\nAs a reminder, mime-types 2.x is no longer compatible with Ruby 1.8 and\nmime-types 1.x is only being maintained for security issues. No new MIME types\nor features will be added.\n\nmime-types (previously called MIME::Types for Ruby) was originally based on\nMIME::Types for Perl by Mark Overmeer, copyright 2001 - 2009. It is built to\nconform to the MIME types of RFCs 2045 and 2231. It tracks the {IANA Media\nTypes registry}[https://www.iana.org/assignments/media-types/media-types.xhtml]\nwith some types added by the users of mime-types."
  s.email = ["halostatue@gmail.com"]
  s.extra_rdoc_files = ["Contributing.rdoc", "History-Types.rdoc", "History.rdoc", "Licence.rdoc", "Manifest.txt", "README.rdoc", "docs/COPYING.txt", "docs/artistic.txt"]
  s.files = ["Contributing.rdoc", "History-Types.rdoc", "History.rdoc", "Licence.rdoc", "Manifest.txt", "README.rdoc", "docs/COPYING.txt", "docs/artistic.txt"]
  s.homepage = "https://github.com/halostatue/mime-types/"
  s.licenses = ["MIT", "Artistic 2.0", "GPL-2"]
  s.rdoc_options = ["--main", "README.rdoc"]
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.2")
  s.rubygems_version = "2.4.3"
  s.summary = "The mime-types library provides a library and registry for information about MIME content type definitions"

  s.installed_by_version = "2.4.3" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<minitest>, ["~> 5.3"])
      s.add_development_dependency(%q<rdoc>, ["~> 4.0"])
      s.add_development_dependency(%q<hoe-doofus>, ["~> 1.0"])
      s.add_development_dependency(%q<hoe-gemspec2>, ["~> 1.1"])
      s.add_development_dependency(%q<hoe-git>, ["~> 1.6"])
      s.add_development_dependency(%q<hoe-rubygems>, ["~> 1.0"])
      s.add_development_dependency(%q<hoe-travis>, ["~> 1.2"])
      s.add_development_dependency(%q<rake>, ["~> 10.0"])
      s.add_development_dependency(%q<simplecov>, ["~> 0.7"])
      s.add_development_dependency(%q<coveralls>, ["~> 0.7"])
      s.add_development_dependency(%q<hoe>, ["~> 3.12"])
    else
      s.add_dependency(%q<minitest>, ["~> 5.3"])
      s.add_dependency(%q<rdoc>, ["~> 4.0"])
      s.add_dependency(%q<hoe-doofus>, ["~> 1.0"])
      s.add_dependency(%q<hoe-gemspec2>, ["~> 1.1"])
      s.add_dependency(%q<hoe-git>, ["~> 1.6"])
      s.add_dependency(%q<hoe-rubygems>, ["~> 1.0"])
      s.add_dependency(%q<hoe-travis>, ["~> 1.2"])
      s.add_dependency(%q<rake>, ["~> 10.0"])
      s.add_dependency(%q<simplecov>, ["~> 0.7"])
      s.add_dependency(%q<coveralls>, ["~> 0.7"])
      s.add_dependency(%q<hoe>, ["~> 3.12"])
    end
  else
    s.add_dependency(%q<minitest>, ["~> 5.3"])
    s.add_dependency(%q<rdoc>, ["~> 4.0"])
    s.add_dependency(%q<hoe-doofus>, ["~> 1.0"])
    s.add_dependency(%q<hoe-gemspec2>, ["~> 1.1"])
    s.add_dependency(%q<hoe-git>, ["~> 1.6"])
    s.add_dependency(%q<hoe-rubygems>, ["~> 1.0"])
    s.add_dependency(%q<hoe-travis>, ["~> 1.2"])
    s.add_dependency(%q<rake>, ["~> 10.0"])
    s.add_dependency(%q<simplecov>, ["~> 0.7"])
    s.add_dependency(%q<coveralls>, ["~> 0.7"])
    s.add_dependency(%q<hoe>, ["~> 3.12"])
  end
end
