imageName="<%= imageName %>"<% if (projectType === 'aspnet') { %>
containerName="<%= projectName %>_<%= imageName %>_1"<% } %>
publicPort=<%= portNumber %>

# Kills all running containers of an image and then removes them.
cleanAll () {
    # List all running containers that use $imageName, kill them and then remove them.
    docker kill $(docker ps -a | awk '{ print $1,$2 }' | grep $imageName | awk '{ print $1}') > /dev/null 2>&1;
    docker rm $(docker ps -a | awk '{ print $1,$2 }' | grep $imageName | awk '{ print $1}') > /dev/null 2>&1;
}

# Builds the Docker image.
buildImage () {
    if [[ -z $ENVIRONMENT ]]; then
       ENVIRONMENT="debug"
    fi

    dockerFileName="Dockerfile.$ENVIRONMENT"

    if [[ ! -f $dockerFileName ]]; then
      echo "$ENVIRONMENT is not a valid parameter. File '$dockerFileName' does not exist."
    else
      echo "Building the image $imageName ($ENVIRONMENT)."
      docker build -f $dockerFileName -t $imageName .
    fi
}

# Runs docker-compose.
compose () {
  if [[ -z $ENVIRONMENT ]]; then
    ENVIRONMENT="debug"
  fi

  composeFileName="docker-compose.$ENVIRONMENT.yml"

  if [[ ! -f $composeFileName ]]; then
    echo "$ENVIRONMENT is not a valid parameter. File '$composeFileName' does not exist."
  else
    if [[ "$RemoteDebugging" -eq 1 ]]; then
        export REMOTE_DEBUGGING="1"
    fi

    echo "Running compose file $composeFileName"
    docker-compose -f $composeFileName kill

    if [[ $ENVIRONMENT = "release" ]]; then
      docker-compose -f $composeFileName build
    fi

    docker-compose -f $composeFileName up -d --build<% if (isWebProject) { %>

    if [[ "$RemoteDebugging" -ne 1 ]]; then
        openSite
    fi<% } %>
  fi
}<% if (projectType === 'aspnet') { %>

debug () {
    url="http://localhost:$publicPort"
    if [[ ! -z $MachineName ]]; then
        url="http://$(docker-machine ip $MachineName):$publicPort"
    fi
    echo  "Running on $url"
    
    containerId=$(docker ps -f "name=$containerName" -q -n=1)
    if [[ -z containerId ]]; then
        echo "Could not find a contianer nammed $containerName"
    else
        eval "docker exec -i $containerId $Command"
    fi
}<% } %><% if (isWebProject) { %>

openSite () {
    url="http://localhost:$publicPort"
    if [[ ! -z $MachineName ]]; then
        url="http://$(docker-machine ip $MachineName):$publicPort"
    fi
    printf 'Opening site'
    until $(curl --output /dev/null --silent --head --fail $url); do
      printf '.'
      sleep 1
    done

    # Open the site.
    open $url
}<% } %>

setMachine() {
    if [[ ! -z $MachineName ]]; then
        eval $(docker-machine env $MachineName)
    fi
}

# Shows the usage for the script.
showUsage () {
    echo "Usage: dockerTask.sh [COMMAND] (ENVIRONMENT) (MachineName)"
    echo "    Runs build or compose using specific environment (if not provided, debug environment is used)"
    echo ""
    echo "Commands:"
    echo "    build: Builds a Docker image ('$imageName')."
    echo "    compose: Builds the images and runs docker-compose. Images are re-built when using release environment, while debug environment uses a cached version of the image."
    echo "    clean: Removes the image '$imageName' and kills all containers based on that image."
    echo ""
    echo "Environments:"
    echo "    debug: Uses debug environment for build and/or compose."
    echo "    release: Uses release environment for build and/or compose."
    echo ""
    echo "MachineName:"
    echo "    Name of the docker-machine to use. Do not provide or use '' to not run docker-machine"
    echo ""
    echo "Example:"
    echo "    ./dockerTask.sh build debug Default"
    echo ""
    echo "    This will:"
    echo "        Build a Docker image named $imageName using debug environment running against the machine default."
}

if [ $# -eq 0 ]; then
  showUsage
else
  case "$1" in
      "compose")
             ENVIRONMENT=$2
             MachineName=$3
             RemoteDebugging=$4
             setMachine
             compose
             ;;
      "build")
             ENVIRONMENT=$2
             MachineName=$3
             setMachine
             buildImage
             ;;
      "debug")
             MachineName=$2
             # Passing anything from the second argument onward to the command.
             shift 2
             Command=$@
             setMachine
             debug
             ;;
      "clean")
             MachineName=$2
             setMachine
             cleanAll
             ;;
      *)
             showUsage
             ;;
  esac
fi