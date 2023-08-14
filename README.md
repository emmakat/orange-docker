# Orange Data Mining Suite Docker Guide #

This guide provides instructions to run the Orange Data Mining Suite in Docker containers. Orange is an open-source data visualization and analysis tool for both novice and expert users. Running Orange in Docker containers on server infrastructure can provide scalability and ease of management.

## Setup Guide ##
Follow the instructions to create a basic Guacamole setup using Docker: [setup guide](https://www.linode.com/docs/guides/installing-apache-guacamole-through-docker/).

### Create a Common Network ###
Connect each of the instances to the common network named `guacamole`.

```sh
docker network create guacamole
docker network connect guacamole example-mysql
docker network connect guacamole example-guacd
docker network connect guacamole example-guacamole
```
## Start Docker Container ##

## When you have a working Guacamole environment, you can use the command below to spawn additional Orange remote desktop instances. Use the same command to create multiple remote desktop environments. Note that the tag should match the hostname in the web interface and must be unique for each instance.

```tag=orange1  # Define a unique tag for the instance
docker run --name $tag --link example-guacd:guacd --network=guacamole -d orangedm/orange-docker-vnc:v1.0
```
## Change Passwords ##
### Change the user password and VNC password within the container. #[#3](https://github.com/biolab/orange-docker/issues/3) ###
```docker exec -it $tag /bin/bash
passwd orange  # changes orange user password
vncpasswd      # changes password for vnc
```
# Create Connection

Create connections for each Orange image via Settings -> Connections menu. Consult a detailed guide on Guacamole administration if needed. Here are the general steps:

1. Open localhost:<port>/guacamole in a browser.
2. Log in with default user guacadmin and password guacadmin. Remember to change these.
3. Open Settings > Connections, click on New connection.
4. Configure the connection parameters:
   - Edit connections -> name: Display name for the dashboard
   - Edit connections -> protocol: VNC
   - Concurrency limits (both): Set as needed
   - Parameters -> Network -> hostname: Equals to $tag
   - Parameters -> Network -> port: 5901
   - Parameters -> Authentication -> Username: orange
   - Parameters -> Authentication -> Password: Password assigned previously

## Sharing Screen

If you wish to share screens, follow these steps:

1. Go to Settings -> Connections.
2. Click on New sharing profile. Name the profile.
3. Check Read only if you want to restrict users to view only.
4. Click Save.

## Stop Instances

To stop the remote desktop instance, use:
\`\`\`bash
docker stop orange1
\`\`\`
