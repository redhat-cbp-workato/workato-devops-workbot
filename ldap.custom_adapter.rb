{
  title: 'LDAP',
  secure_tunnel: true,
  connection: {
    fields: [
      { name: 'profile', optional: false,
        hint: 'LDAP server connection profile' },
      { name: 'host', label: 'Host',
        hint: 'Enter LDAP server hostname or IP address (e.g., ldap.example.com or 192.168.1.100)',
        optional: false },
      { name: 'port', label: 'Port', optional: false,
        control_type: 'integer',
        hint: 'Enter port number (e.g., 389 for LDAP, 636 for LDAPS)' },
      { name: 'isSSL', label: 'is LDAPS', optional: false,
        control_type: 'checkbox',
        hint: 'Is port SSL enabled?' },
      { name: 'baseDN', label: 'BaseDN', optional: false,
        hint: 'Enter base DN in DN format (e.g., dc=example,dc=com)' },
      { name: 'userDNb', label: 'User DN', optional: false,
        hint: 'Enter the full Distinguished Name (DN) for authentication. ' \
              'Must be in DN format (e.g., cn=username123,ou=users,dc=example,dc=com)' },
      { name: 'password', label: 'Password',
        optional: false, control_type: 'password',
        hint: 'Enter credential password' },
      { name: 'sslProtocol', label: 'sslProtocol', optional: false,
        hint: 'Enter SSL protocol version (e.g., SSLv3)' }
    ],

    authorization: {
      type: 'custom',

      acquire: lambda do |connection|
        payload = {
          host: connection['host'], port: connection['port'], baseDN: connection['baseDN'],
          userDNb: connection['userDNb'], password: connection['password'],
          isSSL: connection['isSSL'], sslProtocol: connection['sslProtocol'],
          version: call('required_extension_version')
        }

        post("http://localhost/ext/#{connection['profile']}/connect", payload).
          headers('X-Workato-Connector': 'enforce').
          after_error_response(/.*/) do |_code, body, _header, message|
            error("#{message}: #{body}")
          end
      end,

      apply: lambda do |_connection|
        headers('X-Workato-Connector': 'enforce')
      end
    },

    base_uri: lambda do |connection|
      "http://localhost/ext/#{connection['profile']}/"
    end
  },

  test: lambda do |_connection|
    post('search', { filter: '(objectClass=*)', limit: 1 }).
      after_error_response(/.*/) do |_code, body, _header, message|
        error("#{message}: #{body}")
      end
  end,

  # custom_action: true,
  # custom_action_help: {
  #   body: 'Build your own OpenLDAP action with a HTTP request. ' \
  #   'The request will be authorized with your OpenLDAP connection.'
  # },

  methods: {
    required_extension_version: lambda do
      2
    end,

    string_to_array: lambda do |field|
      field.split(',')
    end,

    format_filter: lambda do |field|
      if field.starts_with?('(') && field.ends_with?(')')
        field
      else
        "(#{field})"
      end
    end
  },

  object_definitions: {
    search_object_input: {
      fields: lambda do |_connection, _config_fields, _object_definitions|
        [
          { name: 'filter', label: 'Search filter', optional: false,
            hint: 'Provide the search filter. E.g. (objectClass=*)',
            convert_input: 'format_filter' },
          { name: 'attributes', label: 'Response Attributes', sticky: true,
            hint: 'Multiple values can be seperated by comma. E.g. cn,un,uid.',
            convert_input: 'string_to_array' },
          { name: 'scope', label: 'Search Scope',
            control_type: 'select', sticky: true,
            pick_list: [
              %w[OBJECT 0],
              %w[ONELEVEL 1],
              %w[SUBTREE 2]
            ],
            convert_input: 'integer_conversion',
            hint: 'Select from list.',
            toggle_hint: 'Select from list',
            toggle_field: {
              name: 'scope', label: 'Search Scope',
              type: 'integer', control_type: 'integer',
              optional: true,
              convert_input: 'integer_conversion',
              toggle_hint: 'Use custom value',
              hint: 'E.g 2 - SUBTREE.'
            } },
          { name: 'base_dn', label: 'Base DN', sticky: true },
          { name: 'limit', label: 'Limit', sticky: true,
            convert_input: 'integer_conversion' },
          { name: 'page_number', label: 'Page Number', sticky: true,
            convert_input: 'integer_conversion' },
          { name: 'output',
            control_type: 'schema-designer',
            sample_data_type: 'json_input',
            extends_schema: false,
            schema_neutral: true,
            sticky: true }
        ]
      end
    },

    search_object_output: {
      fields: lambda do |_connection, config_fields, _object_definitions|
        next [] if config_fields.blank?

        [
          { name: 'records', type: 'array', of: 'object',
            properties: parse_json(config_fields['output'].presence || '[]') }
        ]
      end
    },

    add_object_input: {
      fields: lambda do |_connection, _config_fields, _object_definitions|
        [
          # Required Distinguished Name (DN) Components
          { name: 'dn', label: 'Distinguished name (DN)', optional: false, sticky: true,
            hint: 'E.g: cn=Bob,ou=Users,dc=example,dc=com' },
          { name: 'cn', label: 'Common name (cn)', optional: false, hint: 'E.g: Bob' },
          { name: 'ou', label: 'Organizational unit (ou)', optional: false, hint: 'E.g: Users' },
          # Other DN Components
          { name: 'c', label: 'Country name (c)', optional: true, hint: 'E.g: US' },
          { name: 'st', label: 'State or province (st)', optional: true, hint: 'E.g: California' },
          { name: 'l', label: 'Locality (l)', optional: true, hint: 'E.g: San Francisco' },
          { name: 'o', label: 'Organization name (o)', optional: true, hint: 'E.g: Example Corp' },
          # User-related Attributes
          { name: 'uid', label: 'User ID (uid)', optional: true },
          { name: 'sn', label: 'Surname (sn)', optional: true },
          { name: 'givenName', label: 'First name (givenName)', optional: true },
          { name: 'mail', label: 'Email address (mail)', optional: true },
          { name: 'telephoneNumber', label: 'Telephone number', optional: true },
          { name: 'mobile', label: 'Mobile number', optional: true },
          { name: 'homePhone', label: 'Home phone number', optional: true },
          { name: 'postalAddress', label: 'Mailing address', optional: true },
          { name: 'postalCode', label: 'Postal code', optional: true },
          { name: 'street', label: 'Street address', optional: true },
          # Authentication & Security
          { name: 'userPassword', label: "User's password", optional: true },
          { name: 'shadowLastChange', label: 'Last password Change', optional: true },
          { name: 'shadowMax', label: 'Maximum days between password Changes', optional: true },
          { name: 'shadowExpire', label: 'Account expiration date', optional: true },
          # Group & Role Management
          { name: 'memberOf', label: 'Groups the user belongs to', optional: true },
          { name: 'member', label: 'Members of a group', optional: true },
          { name: 'roleOccupant', label: 'Roles assigned to an entry', optional: true },
          # Object Classification
          { name: 'objectClasses', label: 'Object class', type: 'string', optional: false,
            sticky: true,
            hint: 'E.g: inetOrgPerson, organizationalPerson,
             posixAccount, groupOfNames (Comma separated)' },
          # POSIX / UNIX Attributes
          { name: 'uidNumber', label: 'User ID number', optional: true },
          { name: 'gidNumber', label: 'Group ID number', optional: true },
          { name: 'homeDirectory', label: 'Home directory path', optional: true },
          { name: 'loginShell', label: 'Default login shell', optional: true },
          {
            name: 'attributes',
            label: 'attributes',
            type: 'array', # Enables multiple key-value pairs
            of: 'object',
            properties: [
              { name: 'name', label: 'Attribute name', type: 'string', optional: true },
              { name: 'value', label: 'Attribute value', type: 'string', optional: true }
            ],
            optional: false
          }
        ]
      end
    },

    add_Delete_update_object_output: {
      fields: lambda do |_connection, _config_fields, _object_definitions|
        [
          { name: 'success', type: 'boolean' },
          { name: 'message', type: 'string' }
        ]
      end
    },

    delete_object_input: {
      fields: lambda do |_connection, _config_fields, _object_definitions|
        [
          { name: 'dn', label: 'Distinguished name (DN)', optional: false, sticky: true,
            hint: 'E.g: cn=John Doe,ou=Users,dc=example,dc=com' }
        ]
      end
    },

    update_object_input: {
      fields: lambda do |_connection, _config_fields, _object_definitions|
                [
                  { name: 'dn', label: 'Distinguished name (DN)', optional: false, sticky: true,
                    hint: 'E.g., cn=Bob,ou=Users,dc=example,dc=com' },
                  {
                    name: 'attributes',
                    label: 'attributes',
                    type: 'array', # Enables multiple key-value pairs
                    of: 'object',
                    properties: [
                      { name: 'name', label: 'Attribute name', type: 'string', optional: false },
                      { name: 'value', label: 'Attribute value', type: 'string', optional: false }
                    ],
                    optional: false
                  }
                ]
              end
    }
  },

  actions: {
    search_records: {
      title: 'Search records',
      subtitle: 'Search records in OpenLDAP',
      description: lambda do |_input, _search_object_list|
        "Search <span class='provider'>records</span> " \
        'in <span class="provider">OpenLDAP</span>'
      end,

      help: 'Returns all records that matches your search criteria.',

      input_fields: lambda do |object_definitions|
        object_definitions['search_object_input']
      end,
      execute: lambda do |_connection, input|
        post('search', input.except('output')).
          after_error_response(/.*/) do |_code, body, _header, message|
            error("#{message}: #{body}")
          end
      end,
      output_fields: lambda do |object_definitions|
        object_definitions['search_object_output']
      end
    },
    add_record: {
      title: 'Add record',
      subtitle: 'Add a new record to OpenLDAP',
      description: "Add a <span class='provider'>record</span> to
       <span class='provider'>OpenLDAP</span>",
      help: 'Creates a new LDAP entry with the specified attributes.',
      input_fields: lambda do |object_definitions|
                      object_definitions['add_object_input']
                    end,

      execute: lambda do |_connection, input|
        post('add', input).
          after_error_response(/.*/) do |_code, body, _header, message|
          error("#{message}: #{body}")
        end
      end,

      output_fields: lambda do |object_definitions|
                       object_definitions['add_Delete_update_object_output']
                     end,
      sample_output: lambda do
                       {
                         success: 'true',
                         message: 'Entry added successfully.'
                       }
                     end
    },
    delete_record: {
      title: 'Delete record',
      subtitle: 'Delete an existing record from OpenLDAP',
      description: "Delete a <span class='provider'>record</span>
                   from <span class='provider'>OpenLDAP</span>",
      help: 'Removes an existing LDAP entry based on the provided Distinguished Name (DN).',

      input_fields: lambda do |object_definitions|
                      object_definitions['delete_object_input']
                    end,

      execute: lambda do |_connection, input|
        delete('delete', input).
          after_error_response(/.*/) do |_code, body, _header, message|
          error("#{message}: #{body}")
        end
      end,

      output_fields: lambda do |object_definitions|
                       object_definitions['add_Delete_update_object_output']
                     end,
      sample_output: lambda do
                       {
                         success: 'true',
                         message: 'Entry deleted successfully.'
                       }
                     end
    },
    update_record: {
      title: 'Update record',
      subtitle: 'Update an existing record in OpenLDAP',
      description: "Update a <span class='provider'>record</span>
       in <span class='provider'>OpenLDAP</span>",
      help: 'Updates attributes of an existing LDAP entry based on DN.',

      input_fields: lambda do |object_definitions|
                      object_definitions['update_object_input']
                    end,

      execute: lambda do |_connection, input|
        put('update', input).
          after_error_response(/.*/) do |_code, body, _header, message|
          error("#{message}: #{body}")
        end
      end,

      output_fields: lambda do |object_definitions|
                       object_definitions['add_Delete_update_object_output']
                     end,
      sample_output: lambda do
                       {
                         success: 'true',
                         message: 'Entry modified successfully.'
                       }
                     end
    }
  }
}