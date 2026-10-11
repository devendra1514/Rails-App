# frozen_string_literal: true

# Pagy initializer file (43.4.4)
# See https://ddnexus.github.io/pagy/toolbox/configuration/initializer/

require "pagy"

############ Global Options ################################################################
# See https://ddnexus.github.io/pagy/toolbox/configuration/options/ for details.
# Add your global options below. They will be applied globally.

Pagy::OPTIONS[:limit] = 20 # Limit the items per page
Pagy::OPTIONS[:client_max_limit] = 100 # The client is allowed to request a limit up to 100

Pagy::OPTIONS.freeze
