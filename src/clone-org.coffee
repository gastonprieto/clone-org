_ = require "lodash"
fp = require "lodash/fp"
PagesToStream = require "pages-to-stream"
GitHubClient = require "github"
inquirer = require "inquirer"

action = _.curry (client, organization, lastResponse) ->
  $promise = if lastResponse? then client.getNextPage lastResponse else client.repos.getForOrg { org: organization }

  $promise.then (res) ->
    items: res.data
    nextToken: if client.hasNextPage(res) then res


inquirer.prompt [
  { name: "username", message: "Username?" }
  { name: "password", message: "Password?", type: "password" }
  { name: "organization", message: "Organization?" }
]
.then ({ username, password, organization }) ->
  client = new GitHubClient
    debug: false
    protocol: "https"
    Promise: require "bluebird"

  client.authenticate {
    type: "basic"
    username
    password
  }

  new PagesToStream action(client, organization)
  .stream()
  .map fp.property "clone_url"
  .tap console.log
  .toPromise()
