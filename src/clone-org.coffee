fp = require "lodash/fp"
PagesToStream = require "pages-to-stream"
GitHubClient = require "github"

username = ""
password = ""
org = ""

client = new GitHubClient
  debug: false
  protocol: "https"
  Promise: require "bluebird"

client.authenticate {
  type: "basic"
  username
  password
}

action = (lastResponse) ->
  $promise = if lastResponse? then client.getNextPage lastResponse else client.repos.getForOrg { org }

  $promise.then (res) ->
    items: res.data
    nextToken: if client.hasNextPage(res) then res


new PagesToStream(action).stream()
  .map fp.property "clone_url"
  .tap console.log
  .subscribe()
