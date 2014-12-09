# -*- ruby encoding: utf-8 -*-

require 'mime'
require 'json'

# The definition of one MIME content-type.
#
# == Usage
#  require 'mime/types'
#
#  plaintext = MIME::Types['text/plain'].first
#  # returns [text/plain, text/plain]
#  text = plaintext.first
#  print text.media_type           # => 'text'
#  print text.sub_type             # => 'plain'
#
#  puts text.extensions.join(" ")  # => 'asc txt c cc h hh cpp'
#
#  puts text.encoding              # => 8bit
#  puts text.binary?               # => false
#  puts text.ascii?                # => true
#  puts text == 'text/plain'       # => true
#  puts MIME::Type.simplified('x-appl/x-zip') # => 'appl/zip'
#
#  puts MIME::Types.any? { |type|
#    type.content_type == 'text/plain'
#  }                               # => true
#  puts MIME::Types.all?(&:registered?)
#                                  # => false
class MIME::Type
  # Reflects a MIME content-type specification that is not correctly
  # formatted (it isn't +type+/+subtype+).
  class InvalidContentType < ArgumentError
    # :stopdoc:
    def initialize(type_string)
      @type_string = type_string
    end

    def to_s
      "Invalid Content-Type #{@type_string.inspect}"
    end
    # :startdoc:
  end

  # Reflects an unsupported MIME encoding.
  class InvalidEncoding < ArgumentError
    # :stopdoc:
    def initialize(encoding)
      @encoding = encoding
    end

    def to_s
      "Invalid Encoding #{@encoding.inspect} (valid values: #{VALID_ENCODINGS.inspect})."
    end
    # :startdoc:
  end

  # The released version of the mime-types library.
  VERSION = '2.4.3'

  include Comparable

  MEDIA_TYPE_RE     = %r{([-\w.+]+)/([-\w.+]*)}o
  UNREGISTERED_RE   = %r{[Xx]-}o
  I18N_RE           = %r{[^[:alnum:]]}o
  PLATFORM_RE       = %r{#{RUBY_PLATFORM}}o

  DEFAULT_ENCODINGS = [ nil, :default ]
  BINARY_ENCODINGS  = %w(base64 8bit)
  TEXT_ENCODINGS    = %w(7bit quoted-printable)
  VALID_ENCODINGS   = DEFAULT_ENCODINGS + BINARY_ENCODINGS + TEXT_ENCODINGS

  IANA_URL          = "http://www.iana.org/assignments/media-types/%s/%s"
  RFC_URL           = "http://rfc-editor.org/rfc/rfc%s.txt"
  DRAFT_URL         = "http://datatracker.ietf.org/public/idindex.cgi?command=id_details&filename=%s"
  CONTACT_URL       = "http://www.iana.org/assignments/contact-people.htm#%s"

  if respond_to? :private_constant
    private_constant :MEDIA_TYPE_RE, :UNREGISTERED_RE, :I18N_RE, :PLATFORM_RE,
      :DEFAULT_ENCODINGS, :BINARY_ENCODINGS, :TEXT_ENCODINGS, :VALID_ENCODINGS,
      :IANA_URL, :RFC_URL, :DRAFT_URL, :CONTACT_URL
  end

  # Builds a MIME::Type object from the provided MIME Content Type value
  # (e.g., 'text/plain' or 'applicaton/x-eruby'). The constructed object is
  # yielded to an optional block for additional configuration, such as
  # associating extensions and encoding information.
  #
  # * When provided a Hash or a MIME::Type, the MIME::Type will be
  #   constructed with #init_with.
  # * When provided an Array, the MIME::Type will be constructed only using
  #   the first two elements of the array as the content type and
  #   extensions.
  # * Otherwise, the content_type will be used as a string.
  def initialize(content_type) # :yields self:
    self.system      = nil
    self.obsolete    = false
    self.registered  = nil
    self.use_instead = nil
    self.signature   = nil

    case content_type
    when Hash
      init_with(content_type)
    when Array
      self.content_type = content_type[0]
      self.extensions   = content_type[1] || []
    when MIME::Type
      init_with(content_type.to_h)
    else
      self.content_type = content_type
    end

    self.extensions   ||= []
    self.docs         ||= nil
    self.encoding     ||= :default
    self.friendly({})
    # This value will be deprecated in the future, as it will be an
    # alternative view on #xrefs. Silence an unnecessary warning for now by
    # assigning directly to the instance variable.
    @references       ||= []
    self.xrefs        ||= {}

    yield self if block_given?
  end

  # Returns +true+ if the simplified type matches the current
  def like?(other)
    if other.respond_to?(:simplified)
      @simplified == other.simplified
    else
      @simplified == MIME::Type.simplified(other)
    end
  end

  # Compares the MIME::Type against the exact content type or the simplified
  # type (the simplified type will be used if comparing against something
  # that can be treated as a String with #to_s). In comparisons, this is
  # done against the lowercase version of the MIME::Type.
  def <=>(other)
    if other.respond_to?(:content_type)
      @content_type.downcase <=> other.content_type.downcase
    elsif other.respond_to?(:to_s)
      @simplified <=> MIME::Type.simplified(other.to_s)
    end
  end

  # Compares the MIME::Type based on how reliable it is before doing a
  # normal <=> comparison. Used by MIME::Types#[] to sort types. The
  # comparisons involved are:
  #
  # 1. self.simplified <=> other.simplified (ensures that we
  #    don't try to compare different types)
  # 2. IANA-registered definitions < other definitions.
  # 3. Generic definitions < platform definitions.
  # 3. Complete definitions < incomplete definitions.
  # 4. Current definitions < obsolete definitions.
  # 5. Obselete with use-instead references < obsolete without.
  # 6. Obsolete use-instead definitions are compared.
  def priority_compare(other)
    pc = simplified <=> other.simplified
    if pc.zero?
      pc = if (reg = registered?) != other.registered?
             reg ? -1 : 1 # registered < unregistered
           elsif (plat = platform?(true)) != other.platform?(true)
             plat ? 1 : -1 # generic < platform
           elsif (comp = complete?) != other.complete?
             comp ? -1 : 1 # complete < incomplete
           elsif (obs = obsolete?) != other.obsolete?
             obs ? 1 : -1 # current < obsolete
           elsif obs and ((ui = use_instead) != (oui = other.use_instead))
             if ui.nil?
               1
             elsif oui.nil?
               -1
             else
               ui <=> oui
             end
           else
             0
           end
    end

    pc
  end

  # Returns +true+ if the other object is a MIME::Type and the content types
  # match.
  def eql?(other)
    other.kind_of?(MIME::Type) and self == other
  end

  # Returns the whole MIME content-type string.
  #
  #   text/plain        => text/plain
  #   x-chemical/x-pdb  => x-chemical/x-pdb
  attr_reader :content_type
  # Returns the media type of the simplified MIME::Type.
  #
  #   text/plain        => text
  #   x-chemical/x-pdb  => chemical
  attr_reader :media_type
  # Returns the media type of the unmodified MIME::Type.
  #
  #   text/plain        => text
  #   x-chemical/x-pdb  => x-chemical
  attr_reader :raw_media_type
  # Returns the sub-type of the simplified MIME::Type.
  #
  #   text/plain        => plain
  #   x-chemical/x-pdb  => pdb
  attr_reader :sub_type
  # Returns the media type of the unmodified MIME::Type.
  #
  #   text/plain        => plain
  #   x-chemical/x-pdb  => x-pdb
  attr_reader :raw_sub_type
  # The MIME types main- and sub-label can both start with <tt>x-</tt>,
  # which indicates that it is a non-registered name. Of course, after
  # registration this flag can disappear, adds to the confusing
  # proliferation of MIME types. The simplified string has the <tt>x-</tt>
  # removed and are translated to lowercase.
  #
  #   text/plain        => text/plain
  #   x-chemical/x-pdb  => chemical/pdb
  attr_reader :simplified

  # The list of extensions which are known to be used for this MIME::Type.
  # Non-array values will be coerced into an array with #to_a. Array values
  # will be flattened, +nil+ values removed, and made unique.
  attr_reader :extensions
  def extensions=(ext) # :nodoc:
    @extensions = Array(ext).flatten.compact.uniq
  end

  # Merge the extensions provided into this MIME::Type. The extensions added
  # will be merged uniquely.
  def add_extensions(*ext)
    self.extensions = self.extensions + ext
  end

  ##
  # The preferred extension for this MIME type, if one is set.
  #
  # :attr_reader: preferred_extension

  ##
  def preferred_extension
    extensions.first
  end

  # The encoding (7bit, 8bit, quoted-printable, or base64) required to
  # transport the data of this content type safely across a network, which
  # roughly corresponds to Content-Transfer-Encoding. A value of +nil+ or
  # <tt>:default</tt> will reset the #encoding to the #default_encoding for
  # the MIME::Type. Raises ArgumentError if the encoding provided is
  # invalid.
  #
  # If the encoding is not provided on construction, this will be either
  # 'quoted-printable' (for text/* media types) and 'base64' for eveything
  # else.
  attr_reader :encoding
  def encoding=(enc) # :nodoc:
    if DEFAULT_ENCODINGS.include?(enc)
      @encoding = self.default_encoding
    elsif BINARY_ENCODINGS.include?(enc) or TEXT_ENCODINGS.include?(enc)
      @encoding = enc
    else
      raise InvalidEncoding, enc
    end
  end

  # If the MIME::Type is a system-specific MIME::Type, returns the regular
  # expression for the operating system indicated.
  #
  # This information about MIME content types is deprecated.
  def system
    MIME.deprecated(self, __method__)
    @system
  end

  def system=(os) # :nodoc:
    if os.nil? or os.kind_of?(Regexp)
      @system = os
    else
      @system = %r|#{os}|
    end
  end

  # Returns the default encoding for the MIME::Type based on the media type.
  def default_encoding
    (@media_type == 'text') ? 'quoted-printable' : 'base64'
  end

  ##
  # Returns the media type or types that should be used instead of this
  # media type, if it is obsolete. If there is no replacement media type, or
  # it is not obsolete, +nil+ will be returned.
  def use_instead
    return nil unless obsolete?
    @use_instead
  end
  attr_writer :use_instead # :nodoc:

  # Returns +true+ if the media type is obsolete.
  def obsolete?
    !!@obsolete
  end

  def obsolete=(v) # :nodoc:
    @obsolete = !!v
  end

  # The documentation for this MIME::Type.
  attr_accessor :docs

  # A friendly short description for this MIME::Type.
  #
  # call-seq:
  #   text_plain.friendly         # => "Text File"
  #   text_plain.friendly('en')   # => "Text File"
  def friendly(lang = 'en')
    @friendly ||= {}

    case lang
    when String
      @friendly[lang]
    when Array
      @friendly.merge!(Hash[*lang])
    when Hash
      @friendly.merge!(lang)
    else
      raise ArgumentError
    end
  end

  # A key suitable for use as a lookup key for translations, such as with
  # the I18n library.
  #
  # call-seq:
  #    text_plain.i18n_key # => "text.plain"
  #    3gpp_xml.i18n_key   # => "application.vnd-3gpp-bsf-xml"
  #      # from application/vnd.3gpp.bsf+xml
  #    x_msword.i18n_key   # => "application.word"
  #      # from application/x-msword
  attr_reader :i18n_key

  # The encoded references URL list for this MIME::Type. See #urls for more
  # information.
  #
  # This was previously called #url.
  attr_reader :references
  def references=(r) # :nodoc:
    MIME.deprecated(self, __method__)
    @references = Array(r).flatten.compact.uniq
  end

  def url # :nodoc:
    MIME.deprecated(self, __method__, "and has been renamed to #references")
    references
  end

  def url=(r) # :nodoc:
    MIME.deprecated(self, __method__)
    self.references = r
  end

  # The cross-references list for this MIME::Type.
  attr_reader :xrefs
  def xrefs=(x) # :nodoc:
    @xrefs = MIME::Types::Container.new.merge(x)
    @xrefs.each_value(&:sort!)
    @xrefs.each_value(&:uniq!)
  end

  # The decoded URL list for this MIME::Type.
  #
  # The special URL value IANA will be translated into:
  #   http://www.iana.org/assignments/media-types/<mediatype>/<subtype>
  #
  # The special URL value RFC### will be translated into:
  #   http://www.rfc-editor.org/rfc/rfc###.txt
  #
  # The special URL value DRAFT:name will be translated into:
  #   https://datatracker.ietf.org/public/idindex.cgi?
  #       command=id_detail&filename=<name>
  #
  # The special URL value [token] will be translated into:
  #   http://www.iana.org/assignments/contact-people.htm#<token>
  #
  # These values will be accessible through #urls, which always returns an
  # array.
  def urls
    references.map do |el|
      case el
      when %r{^IANA$}
        IANA_URL % [ @media_type, @sub_type ]
      when %r{^RFC(\d+)$}
        RFC_URL % $1
      when %r{^DRAFT:(.+)$}
        DRAFT_URL % $1
      when %r{^\{([^=]+)=([^\}]+)\}}
        [$1, $2]
      when %r{^\[([^=]+)=([^\]]+)\]}
        [$1, CONTACT_URL % $2]
      when %r{^\[([^\]]+)\]}
        CONTACT_URL % $1
      else
        el
      end
    end
  end

  # The decoded cross-reference URL list for this MIME::Type.
  def xref_urls
    xrefs.map { |(type, values)|
      case type
      when 'rfc'
        values.map { |data| "http://www.iana.org/go/#{data}" }
      when 'draft'
        values.map { |data|
          "http://www.iana.org/go/#{data.sub(/\ARFC/, 'draft')}"
        }
      when 'rfc-errata'
        values.map { |data|
          "http://www.rfc-editor.org/errata_search.php?eid=#{data}"
        }
      when 'person'
        values.map { |data|
          "http://www.iana.org/assignments/media-types/media-types.xhtml##{data}"
        }
      when 'template'
        values.map { |data|
          "http://www.iana.org/assignments/media-types/#{data}"
        }
      else # 'uri', 'text', etc.
        values
      end
    }.flatten
  end

  # Prior to BCP 178 (RFC 6648), it could be assumed that MIME content types
  # that start with <tt>x-</tt> were unregistered MIME. Per this BCP, this
  # assumption is no longer being made by default in this library.
  #
  # There are three possible registration states for a MIME::Type:
  # - Explicitly registered, like application/x-www-url-encoded.
  # - Explicitly not registered, like image/webp.
  # - Unspecified, in which case the media-type and the content-type will be
  #   scanned to see if they start with <tt>x-</tt>, indicating that they
  #   are assumed unregistered.
  def registered?
    if @registered.nil?
      (@raw_media_type !~ UNREGISTERED_RE) and
        (@raw_sub_type !~ UNREGISTERED_RE)
    else
      !!@registered
    end
  end

  def registered=(v) # :nodoc:
    @registered = v.nil? ? v : !!v
  end

  # MIME types can be specified to be sent across a network in particular
  # formats. This method returns +true+ when the MIME::Type encoding is set
  # to <tt>base64</tt>.
  def binary?
    BINARY_ENCODINGS.include?(@encoding)
  end

  # MIME types can be specified to be sent across a network in particular
  # formats. This method returns +false+ when the MIME::Type encoding is
  # set to <tt>base64</tt>.
  def ascii?
    not binary?
  end

  # Returns +true+ when the simplified MIME::Type is in the list of known
  # digital signatures.
  def signature?
    !!@signature
  end

  def signature=(v) # :nodoc:
    @signature = !!v
  end

  # Returns +true+ if the MIME::Type is specific to an operating system.
  #
  # This method is deprecated.
  def system?(__internal__ = false)
    MIME.deprecated(self, __method__) unless __internal__
    not @system.nil?
  end

  # Returns +true+ if the MIME::Type is specific to the current operating
  # system as represented by RUBY_PLATFORM.
  #
  # This method is deprecated.
  def platform?(__internal__ = false)
    MIME.deprecated(self, __method__) unless __internal__
    system?(__internal__) and (RUBY_PLATFORM =~ @system)
  end

  # Returns +true+ if the MIME::Type specifies an extension list,
  # indicating that it is a complete MIME::Type.
  def complete?
    not @extensions.empty?
  end

  # Returns the MIME::Type as a string.
  def to_s
    @content_type
  end

  # Returns the MIME::Type as a string for implicit conversions. This allows
  # MIME::Type objects to appear on either side of a comparison.
  #
  #   'text/plain' == MIME::Type.new('text/plain')
  def to_str
    @content_type
  end

  # Returns the MIME::Type as an array suitable for use with
  # MIME::Type.from_array.
  #
  # This method is deprecated.
  def to_a
    MIME.deprecated(self, __method__)
    [ @content_type, @extensions, @encoding, @system, obsolete?, @docs,
      @references, registered? ]
  end

  # Returns the MIME::Type as an array suitable for use with
  # MIME::Type.from_hash.
  #
  # This method is deprecated.
  def to_hash
    MIME.deprecated(self, __method__)
    { 'Content-Type'              => @content_type,
      'Content-Transfer-Encoding' => @encoding,
      'Extensions'                => @extensions,
      'System'                    => @system,
      'Obsolete'                  => obsolete?,
      'Docs'                      => @docs,
      'URL'                       => @references,
      'Registered'                => registered?,
    }
  end

  # Converts the MIME::Type to a JSON string.
  def to_json(*args)
    to_h.to_json(*args)
  end

  # Converts the MIME::Type to a hash suitable for use in JSON. The output
  # of this method can also be used to initialize a MIME::Type.
  def to_h
    encode_with({})
  end

  # Populates the +coder+ with attributes about this record for
  # serialization. The structure of +coder+ should match the structure used
  # with #init_with.
  def encode_with(coder)
    coder['content-type']   = @content_type
    coder['docs']           = @docs unless @docs.nil? or @docs.empty?
    coder['friendly']       = @friendly unless @friendly.empty?
    coder['encoding']       = @encoding
    coder['extensions']     = @extensions unless @extensions.empty?
    if obsolete?
      coder['obsolete']     = obsolete?
      coder['use-instead']  = use_instead if use_instead
    end
    coder['references']     = references unless references.empty?
    coder['xrefs']          = xrefs unless xrefs.empty?
    coder['registered']     = registered?
    coder['signature']      = signature? if signature?
    coder['system']         = @system if @system
    coder
  end

  # Initialize an empty object from +coder+, which must contain the
  # attributes necessary for initializing an empty object.
  def init_with(coder)
    self.content_type = coder['content-type']
    self.docs         = coder['docs'] || []
    self.friendly(coder['friendly'] || {})
    self.encoding     = coder['encoding']
    self.extensions   = coder['extensions'] || []
    self.obsolete     = coder['obsolete']
    # This value will be deprecated in the future, as it will be an
    # alternative view on #xrefs. Silence an unnecessary warning for now by
    # assigning directly to the instance variable.
    @references       = Array(coder['references']).flatten.compact.uniq
    self.registered   = coder['registered']
    self.signature    = coder['signature']
    self.system       = coder['system']
    self.xrefs        = coder['xrefs'] || {}
    self.use_instead  = coder['use-instead']
  end
  # :startdoc:

  class << self
    # The MIME types main- and sub-label can both start with <tt>x-</tt>,
    # which indicates that it is a non-registered name. Of course, after
    # registration this flag can disappear, adds to the confusing
    # proliferation of MIME types. The simplified string has the <tt>x-</tt>
    # removed and are translated to lowercase.
    def simplified(content_type)
      matchdata = case content_type
                  when MatchData
                    content_type
                  else
                    MEDIA_TYPE_RE.match(content_type)
                  end

      if matchdata
        matchdata.captures.map { |e|
          e.downcase.gsub(UNREGISTERED_RE, '')
        }.join('/')
      end
    end

    # Converts a provided content type into a translation key suitable for
    # use with the I18n library.
    def i18n_key(content_type)
      matchdata = case content_type
                  when MatchData
                    content_type
                  else
                    MEDIA_TYPE_RE.match(content_type)
                  end

      if matchdata
        matchdata.captures.map { |e|
          e.downcase.gsub(UNREGISTERED_RE, '').gsub(I18N_RE, '-')
        }.join('.')
      end
    end

    # Creates a MIME::Type from an array in the form of:
    #   [type-name, [extensions], encoding, system]
    #
    # +extensions+, +encoding+, and +system+ are optional.
    #
    #   MIME::Type.from_array("application/x-ruby", ['rb'], '8bit')
    #   MIME::Type.from_array(["application/x-ruby", ['rb'], '8bit'])
    #
    # These are equivalent to:
    #
    #   MIME::Type.new('application/x-ruby') do |t|
    #     t.extensions  = %w(rb)
    #     t.encoding    = '8bit'
    #   end
    #
    # This method is deprecated.
    def from_array(*args) # :yields MIME::Type.new:
      MIME.deprecated(self, __method__)

      # Dereferences the array one level, if necessary.
      args = args.first if args.first.kind_of? Array

      unless args.size.between?(1, 8)
        raise ArgumentError, "Array provided must contain between one and eight elements."
      end

      MIME::Type.new(args.shift) do |t|
        t.extensions, t.encoding, t.system, t.obsolete, t.docs, t.references,
          t.registered = *args
        yield t if block_given?
      end
    end

    # Creates a MIME::Type from a hash. Keys are case-insensitive, dashes
    # may be replaced with underscores, and the internal Symbol of the
    # lowercase-underscore version can be used as well. That is,
    # Content-Type can be provided as content-type, Content_Type,
    # content_type, or :content_type.
    #
    # Known keys are <tt>Content-Type</tt>,
    # <tt>Content-Transfer-Encoding</tt>, <tt>Extensions</tt>, and
    # <tt>System</tt>.
    #
    #   MIME::Type.from_hash('Content-Type' => 'text/x-yaml',
    #                        'Content-Transfer-Encoding' => '8bit',
    #                        'System' => 'linux',
    #                        'Extensions' => ['yaml', 'yml'])
    #
    # This is equivalent to:
    #
    #   MIME::Type.new('text/x-yaml') do |t|
    #     t.encoding    = '8bit'
    #     t.system      = 'linux'
    #     t.extensions  = ['yaml', 'yml']
    #   end
    #
    # This method has been deprecated.
    def from_hash(hash) # :yields MIME::Type.new:
      MIME.deprecated(self, __method__)
      type = {}
      hash.each_pair do |k, v|
        type[k.to_s.tr('A-Z', 'a-z').gsub(/-/, '_').to_sym] = v
      end

      MIME::Type.new(type[:content_type]) do |t|
        t.extensions  = type[:extensions]
        t.encoding    = type[:content_transfer_encoding]
        t.system      = type[:system]
        t.obsolete    = type[:obsolete]
        t.docs        = type[:docs]
        t.url         = type[:url]
        t.registered  = type[:registered]

        yield t if block_given?
      end
    end

    # Essentially a copy constructor.
    #
    #   MIME::Type.from_mime_type(plaintext)
    #
    # is equivalent to:
    #
    #   MIME::Type.new(plaintext.content_type.dup) do |t|
    #     t.extensions  = plaintext.extensions.dup
    #     t.system      = plaintext.system.dup
    #     t.encoding    = plaintext.encoding.dup
    #   end
    #
    # This method has been deprecated.
    def from_mime_type(mime_type) # :yields the new MIME::Type:
      MIME.deprecated(self, __method__)
      new(mime_type)
    end
  end

  private
  def content_type=(type_string)
    match = MEDIA_TYPE_RE.match(type_string)
    raise InvalidContentType, type_string if match.nil?

    @content_type                  = type_string
    @raw_media_type, @raw_sub_type = *match.captures
    @simplified                    = MIME::Type.simplified(match)
    @i18n_key                      = MIME::Type.i18n_key(match)
    @media_type, @sub_type         =
      *MEDIA_TYPE_RE.match(@simplified).captures
  end
end
