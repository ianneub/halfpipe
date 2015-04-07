require 'grape'
require 'json'

module Halfpipe
  class APIv1 < Grape::API
    version 'v1', using: :path
    format :json

    get :ping do
      "ok"
    end

    post :recieve_hook do
      payload = JSON.parse params["payload"]

      sha1 = payload['commits'].last['raw_node']
      url = "#{payload['canon_url']}#{payload['repository']['absolute_url'][0..-2]}.git"
      branch = payload['commits'].last['branch']

      {sha1: sha1, url: url, branch: branch}
    end
  end
end
