
# A docker compose for BioPortal API and the Annotator Proxy

## Services provided
This docker compose launches all the services necessary to run ontologies_api and ncbo_cron. The docker files of each of the services above configures them properly to all run together, and bind all the persistent data in the `data/` directory:

* **4store** 
  * http://localhost:9000
  * Data in `data/4store`
* **redis**
  * Data in `data/redis`
  * Port 6379 (except for tests, where we use also 6380 and 6381)
  * 3 servers:
    * redis-goo
    * redis-annotator
    * redis-http
* **solr**
  * http://localhost:8983/solr
  * Data in `data/solr`
* **mgrep**
  * http://localhost:55555
  * Test it using `telnet localhost 55555` > `ANY term_to_annotate`
  * Data in `data/mgrep`
* **bioportal-api**
  * runs nginx/ontologies-api/ncbo_cron/sshd
  * ontologies_api accessible on http://localhost:8080
  * sshd is accessible on the host port 2222 and is used by the administration scripts provided
  * `data/bioportal/repositories` contains the ontologies processed by bioportal 
  * `data/bioportal/reports` contains the reports generated by the processing of ontologies
  * `data/ncbo_logs` contains the logs from ncbo_cron and other processes in ontologies-api
* **bioportal-annotator-proxy**
  * Tomcat with an Annotator proxy
  * http://localhost:8081




## Test environment

If you wish to run the `ncbo_cron` integration tests to check that the containers are set-up properly, run the following script: `00_run_test_containers.sh`, it will run only the containers needed for the test and expose the right ports. Nothing more is needed.




## Quick setup

A quick guide with commands to easily setup a BioPortal appliance on your machine

```shell
./0_purge_data_and_reset.sh
./2_build_containers.sh
./3_initialize.sh
```

* We now need to create the admin user with the apikey `61297daf-147c-40f3-b9b1-a3a2d6b744fa`:

```shell
docker exec -i -t bioportal-api bash
cd /srv/ncbo/ncbo_cron && bin/ncbo_cron --console
```

```ruby
LinkedData::Models::User.new({:username => "admin", :email => "admin@god.org", :role => [LinkedData::Models::Users::Role.find("ADMINISTRATOR").include(:role).first], :password => "password", :apikey => "61297daf-147c-40f3-b9b1-a3a2d6b744fa"}).save
```



* To add a new ontology and submission

```shell
# using pullLocation (here Movie Ontology)
curl -X PUT -H "Content-Type: application/json" -H "Authorization: apikey token=61297daf-147c-40f3-b9b1-a3a2d6b744fa" -d '{ "acronym": "TEST", "name": "Test Ontology", "administeredBy": ["admin"]}' http://localhost:8080/ontologies/TEST

curl -X POST -H "Content-Type: application/json" -H "Authorization: apikey token=0eab1f37-0f43-46ed-a245-5060b2e2eaa5" -d '{"contact": [{"name": "Admin","email": "admin@god.org"}], "ontology": "http://localhost:8080/ontologies/TEST", "hasOntologyLanguage": "OWL", "released": "2013-01-01T16:40:48-08:00", "pullLocation": "http://www.movieontology.org/2010/01/movieontology.owl"}' http://localhost:8080/ontologies/TEST/submissions

# The STY ttl file has been previously put in data/bioportal. So it is in /srv/bioportal in the container (for uploadFilePath param). But not working
curl -X PUT -H "Content-Type: application/json" -H "Authorization: apikey token=61297daf-147c-40f3-b9b1-a3a2d6b744fa" -d '{ "acronym": "STY", "name": "UMLS Semantic Network", "administeredBy": ["admin"]}' http://localhost:8080/ontologies/STY

curl -X POST -H "Content-Type: application/json" -H "Authorization: apikey token=0eab1f37-0f43-46ed-a245-5060b2e2eaa5" -d '{"contact": [{"name": "Admin","email": "admin@god.org"}], "ontology": "http://localhost:8080/ontologies/STY", "hasOntologyLanguage": "UMLS", "released": "2013-01-01T16:40:48-08:00", "uploadFilePath": "/srv/bioportal/umls_semantictypes_2015AA.ttl"}' http://localhost:8080/ontologies/STY/submissions

curl -X POST -H "Content-Type: application/json" -H "Authorization: apikey token=0eab1f37-0f43-46ed-a245-5060b2e2eaa5" -d '{"contact": [{"name": "Admin","email": "admin@god.org"}], "ontology": "http://localhost:8080/ontologies/STY", "hasOntologyLanguage": "UMLS", "released": "2013-01-01T16:40:48-08:00", "uploadFilePath": "/srv/bioportal/repository/umls_semantictypes_2015AA.ttl"}' http://localhost:8080/ontologies/STY/submissions
```





## Deployment and initial setup

The first step in deploying this docker compose is to clone this repository:
```
git clone https://github.com/agroportal/docker-compose-bioportal.git
```

Subsequently, administration scripts are provided to set-up the environment. You may should run them in the following order:

### 0_purge_data_and_reset.sh (Optional)

Erases all the persistant data from the `data` directory. This is useful if you want to reset an already set-up bioportal instance. 

### 1_prepare_data.sh

This script allows you to retrieve all the ontologies you need from NCBO bioportal (English) or LIRMM (French) for the ontologies with no licence restrictions. 

The script takes three arguments:
- The first argument is the portal from which to fetch the ontologies (lirmm or ncbo).
  - The second argument is your api-key from the selected portal (you must create an account for free on the portal to obtain the api-key). 
  - The last argument is the list of ontology acronyms to retrieve from the selected portal (you may find the list of ontologies on the portal). 

If the process is interrupted, you can run the script again, it will not redownload ontologies that were already downloaded before. The ontologies downloaded are saved in the `data/bioportal/repository/` directory, if you mistakingly included an ontology you do not need, you may delete it directly from this directory. 

Alternatively, instead of running this script you may manually put the ontologies in the `data/bioportal/repository/` directory if you already have them with the name ACRONYM.ttl, where ACRONYM is the acronym of each ontology.

### 2_build_containers.sh 
This script will check if you have an ssh key, generate one if need be and add it to the authorized keys for the bioportal-api container. Subsequently, it will run `docker-compose build` to build all the containers prior to running them.

### 3_initialize.sh
This script will run `docker-compose up -d --force-recreate` to start all the containers and services and will then proceed to submit all the ontologies located in the `data/bioportal/repository/`directory. 

The script will show you the submission logs, you must monitor them during the submission process until no more ontologies are being processed for more than a few minutes. At that point you will see the `Finished ontology process queue check` repeatedly without any ontologies starting to be processed. 

You can then interrupt the script. 

rtal docker from running, you will be able to restart it subsequently as instructed below. 

### Day to day operations
Once the appliance is populated and the initial set-up is finished, you may stop your containers as per usual with `docker-compose down`  . To start the containers again, you can use `docker-compose up`

If you wish to start from scratch, you may use the `0_purge_data_optional.sh` script to purge all the data and then repeat the initial setup-process by running scripts from 1 to 5 from the start.

If you wish to update the containers in the docker-compose to use the latest version of `ontologies-api`, `ncbo-cron` and `annotator-proxy`, you can manually rebuild the containers with: `docker-compose build --no-cache bioportal-api` and `docker-compose build --no-cache bioportal-annotator-proxy` .

You then need to restart and recreate the containers: `docker-compose down` and then `docker-compose up --force-recreate`

## Requirements and dependencies on the host machine

Use the latest version of Docker on a linux host with an up to date kernel (prefarably the latest stable release of the upstream branch). 

Warning: The native version of docker for MacOS contains active bugs that cause the docker deamon to hang-up during the indexation process. If you wish to use this docker-compose on a MacOS host, you may want to use docker-toolkit and docker-machine to create a virtualized docker environemnt. Alternatively you may install docker in a virtual machine and deploy docker compose inside the virtual machine. The same may be true on a Windows machine with the native windows version of docker. 

### Utilities required for the deployment process
The depolyment and set-up process requires a number of basic utilities to run:
- curl 
- wget
- ssh (client)


curl is required by `1_prepare_data.sh` and `3_initialize.sh`.

ssh is required for `3_initialize.sh`.

wget is only required for `1_prepare_data`. 
