require 'grape'

module Halfpipe
  class APIv1 < Grape::API
    version 'v1', using: :path
    format :json

    get :ping do
      "ok"
    end
  end
end
