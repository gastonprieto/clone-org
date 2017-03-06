_ = require "lodash"
fp = require "lodash/fp"
Rx = require "rx"
Promise = require "bluebird"
PagesToStream = require "pages-to-stream"
GitHubClient = require "github"
inquirer = require "inquirer"
gitclone = Promise.promisify require "gitclone"

getRepositories = (client) -> (organization) -> (lastResponse) ->
  $promise = if lastResponse? then client.getNextPage lastResponse else client.repos.getForOrg { org: organization }

  $promise.then (res) ->
    items: res.data
    nextToken: if client.hasNextPage res then res

readParameters = ->
  inquirer.prompt [
    { name: "username", message: "Username?" }
    { name: "password", message: "Password?", type: "password" }
    { name: "organization", message: "Organization?" }
  ]

createClient = ({ username, password }) ->
  client = new GitHubClient
    debug: false
    protocol: "https"
    Promise: require "bluebird"

  client.authenticate {
    type: "basic"
    username
    password
  }

cloneRepository = (organization, name) ->
  path = "#{organization}/#{name}"
  console.log "Cloning repository #{name} to #{path}..."
  gitclone path, { dest: path, ssh: true }

readParameters()
.then (opts) ->
  { organization } = opts
  new PagesToStream getRepositories createClient(opts), organization
  .stream()
  .flatMapWithMaxConcurrent 1, ({name}) ->
    Rx.Observable.defer ->
      cloneRepository organization, name
  .toPromise()
