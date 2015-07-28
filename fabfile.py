from bunch import bunchify
from fabric.api import *
from requests.auth import HTTPBasicAuth

import base64
import copy
import datetime
import json
import os
import requests
import ruamel.yaml
import time
import yaml

import pprintpp
pprintpp.monkeypatch()
import pprint

def dict_merge(a, b):
    '''recursively merges dict's. not just simple a['key'] = b['key'], if
    both a and bhave a key who's value is a dict then dict_merge is called
    on both values and the result stored in the returned dictionary.'''
    if not isinstance(b, dict):
        return b
    result = copy.deepcopy(a)
    for k, v in b.iteritems():
        if k in result and isinstance(result[k], dict):
                result[k] = dict_merge(result[k], v)
        else:
            result[k] = copy.deepcopy(v)
    return result

with open('defaults.conf') as defaults_file:
    defaults_file_content = defaults_file.read()
defaults = yaml.load(defaults_file_content)

with open('project.conf') as project_file:
    project_file_content = project_file.read()

project_yaml = ruamel.yaml.load(project_file_content, ruamel.yaml.RoundTripLoader)

project = yaml.load(project_file_content)
project = dict_merge(defaults, project)

if os.path.isfile(os.environ['HOME']+'/ops.conf'): 
    with open(os.environ['HOME']+'/ops.conf') as ops_file:
        ops_file_content = ops_file.read()
    ops = yaml.load(ops_file_content)
    project = dict_merge(project, ops)

if os.path.isfile('private.conf'): 
    with open('private.conf') as private_file:
        private_file_content = private_file.read()
    private = yaml.load(private_file_content)
    project = dict_merge(project, private)

stages = project['web']['stages']


@task
def dev():
    env.hosts = ["localhost"]
    env.host = ["localhost"]
    env.host_string = ["localhost"]
    env.stages = [project["dev"]]


@task
def web():
    env.user = project['web']['admin']['user']
    env.hosts = [project['web']['server']]
    env.host = project['web']['server']
    env.host_string = project['web']['server']
    env.key_filename = 'salt/root/web/files/web.pem'
    

@task
def production():
    env.forward_agent = True
    env.stages = ['production']
    env.hosts = [project['web']['server']]
    env.host = project['web']['server']
    env.host_string = project['web']['server']


@task
def staging():
    env.forward_agent = True
    env.stages = ['staging']
    env.hosts = [project['web']['server']]
    env.host = project['web']['server']
    env.host_string = project['web']['server']


@task
def preview():
    env.forward_agent = True
    env.stages = ['preview']
    env.hosts = [project['web']['server']]
    env.host = project['web']['server']
    env.host_string = project['web']['server']


@task
def all():
    env.forward_agent = True
    env.stages = ['production','staging','preview']
    env.hosts = [project['web']['server']]
    env.host = project['web']['server']
    env.host_string = project['web']['server']


@task
@hosts()
def check():
    #pprint.pprint(env)
    pprint.pprint(project)


@task
@hosts()
def deploy(branch="master"):
    time = datetime.datetime.utcnow().strftime("%Y%m%dT%H%M%S%z")

    for current_stage in env.stages:
        stage = bunchify(stages[current_stage])
        env.user = stage.user

        run("cd $HOME/source && git fetch origin "+branch)
        run("cd $HOME/source && git archive origin/"+branch+" --prefix=$HOME/releases/"+time+"/ | (cd /; tar xf -)")

        run("rm -rf $HOME/current")

        run("ln -s $HOME/releases/"+time+" $HOME/current")

        run("ln -s $HOME/shared/vendor $HOME/current/vendor")
        run("ln -s $HOME/shared/assets $HOME/current/public/assets")
        run("ln -s $HOME/shared/static $HOME/current/public/static")
        run("ln -s $HOME/shared/bower_components $HOME/current/public/static/vendor")

        run("rm -rf $CRAFT_PATH/config")
        run("ln -s $HOME/current/craft/config $CRAFT_PATH/config")

        run("rm -rf $CRAFT_PATH/templates")
        run("ln -s $HOME/current/templates $CRAFT_PATH/templates")

        run("rm -rf $CRAFT_PATH/plugins")
        run("ln -s $HOME/shared/plugins $CRAFT_PATH/plugins")

        run("rm -rf $CRAFT_PATH/storage")
        run("ln -s $HOME/shared/storage $CRAFT_PATH/storage")

        run("cd $HOME/current && bower install")
        run("cd $HOME/current/assets && browserify js/main.js -o js/bundle.js")
        run("harp compile $HOME/current/assets $HOME/shared/static")


@task
@hosts()
def uploads(method):
    for current_stage in env.stages:
        stage = bunchify(stages[current_stage])
        env.user = stage.user

        if method == "up":
            local("rsync -avz --progress "+os.environ['UPLOADS_PATH']+"/ "+env.user+"@"+env.host_string+":/home/"+env.user+"/shared/assets")
        if method == "down":
            local("rsync -avz --progress "+env.user+"@"+env.host_string+":/home/"+env.user+"/shared/assets/ "+os.environ['UPLOADS_PATH'])


@task
@hosts()
def db(method):

    for current_stage in env.stages:
        if isinstance(current_stage, basestring):
            stage = bunchify(stages[current_stage])
        else:
            stage = bunchify(current_stage)

        env.user = stage.user

        if method == "import":
            if env.host == "localhost":
                local("cd /tmp && mysql -u $MYSQL_USER -h localhost -p$MYSQL_PASS $MYSQL_DB < dump.sql")
            else:
                run("cd $HOME/tmp && mysql -u $MYSQL_USER -h localhost -p$MYSQL_PASS $MYSQL_DB < import.sql")
        if method == "dump":
            if env.host == "localhost":
                local("cd /tmp && mysqldump -u $MYSQL_USER -h localhost -p$MYSQL_PASS $MYSQL_DB > dump.sql")
            else:
                run("cd $HOME/tmp && mysqldump -u $MYSQL_USER -h localhost -p$MYSQL_PASS $MYSQL_DB > dump.sql")
        if method == "down":
            get("/home/"+stage.user+"/tmp/dump.sql","/tmp/dump.sql")
        if method == "up":
            put("/tmp/dump.sql","/home/"+stage.user+"/tmp/import.sql")
        if method == "sync":
            run("cd $HOME/tmp && mysqldump -u $MYSQL_USER -h localhost -p$MYSQL_PASS $MYSQL_DB > dump.sql")
            get("/home/"+stage.user+"/tmp/dump.sql","/tmp/dump.sql")
            local("cd /tmp && mysql -u $MYSQL_USER -h localhost -p$MYSQL_PASS $MYSQL_DB < dump.sql")
            


@task
@hosts()
def releases(method="clean"):
    if method == "clean":
        for current_stage in env.stages:
            stage = bunchify(stages[current_stage])
            env.user = stage.user

            output = run("ls $HOME/releases")
            releases = sorted(output.split(), reverse=True)
            keep = 3

            for index, release in enumerate(releases):
                if keep <= index:
                    print "removing =>"
                    print release
                    run("rm -rf $HOME/releases/"+release)
                else:
                    print "keeping =>"
                    print release


@task
@hosts('localhost')
def setup(method=False):

    #
    # Full setup
    #

    if (not method):

        if 'web' not in project_yaml:
            project_yaml['web'] = {}

        local("openssl genrsa -out salt/root/web/files/web.pem 2048")
        local("chmod 600 salt/root/web/files/web.pem")
        local("ssh-keygen -f salt/root/web/files/web.pem -y > salt/root/web/files/web.pub")
        local("ssh-add salt/root/web/files/web.pem")
        local("cp salt/root/web/files/web.pub salt/root/web/files/authorized_keys")

    #
    # AWS
    #

    if (not method) or (method == "aws"):

        if 'aws' not in project_yaml:
            project_yaml['aws'] = {}

        if 'web' not in project_yaml:
            project_yaml['web'] = {}

        with open("salt/root/web/files/web.pub", "rb") as public_key:
            project_yaml['web']['key_fingerprint'] = json.loads(local("aws ec2 import-key-pair --key-name "+project['name']+" --public-key-material \""+public_key.read()+"\"", capture=True))['KeyFingerprint']

        elastic_ip = json.loads(local("aws ec2 allocate-address --domain vpc", capture=True))
        project_yaml['web']['server'] = elastic_ip['PublicIp']
        project_yaml['aws']['elastic_ip'] = elastic_ip['PublicIp']
        project_yaml['aws']['address_allocation_id'] = elastic_ip['AllocationId']

        vpc = json.loads(local("aws ec2 create-vpc --cidr-block 10.0.0.0/16", capture=True))['Vpc']
        print vpc
        project_yaml['aws']['vpc_id'] = vpc['VpcId']

        local("aws ec2 modify-vpc-attribute --vpc-id "+vpc['VpcId']+" --enable-dns-support", capture=True)
        local("aws ec2 modify-vpc-attribute --vpc-id "+vpc['VpcId']+" --enable-dns-hostnames", capture=True)

        internet_gateway = json.loads(local("aws ec2 create-internet-gateway", capture=True))['InternetGateway']
        print internet_gateway
        project_yaml['aws']['internet_gateway_id'] = internet_gateway['InternetGatewayId']

        local("aws ec2 attach-internet-gateway --internet-gateway-id "+internet_gateway['InternetGatewayId']+" --vpc-id "+vpc['VpcId'])

        subnet = json.loads(local("aws ec2 create-subnet --vpc-id "+vpc['VpcId']+" --cidr-block 10.0.0.0/24", capture=True))['Subnet']
        print subnet
        project_yaml['aws']['subnet_id'] = subnet['SubnetId']

        route_table = json.loads(local("aws ec2 create-route-table --vpc-id "+vpc['VpcId'], capture=True))['RouteTable']
        print route_table
        project_yaml['aws']['route_table_id'] = route_table['RouteTableId']

        local("aws ec2 associate-route-table --route-table-id "+route_table['RouteTableId']+" --subnet-id "+subnet['SubnetId'])
        local("aws ec2 create-route --route-table-id "+route_table['RouteTableId']+" --destination-cidr-block 0.0.0.0/0 --gateway-id "+internet_gateway['InternetGatewayId'])

        security_group = json.loads(local("aws ec2 create-security-group --vpc-id "+vpc['VpcId']+"  --group-name "+project['name']+" --description 'Web server.'", capture=True))
        print security_group 

        local("aws ec2 authorize-security-group-ingress --group-id "+security_group['GroupId']+" --protocol tcp --port 22 --cidr 0.0.0.0/0")
        local("aws ec2 authorize-security-group-ingress --group-id "+security_group['GroupId']+" --protocol tcp --port 80 --cidr 0.0.0.0/0")
        local("aws ec2 authorize-security-group-ingress --group-id "+security_group['GroupId']+" --protocol tcp --port 443 --cidr 0.0.0.0/0")

        project_yaml['aws']['security_groups'] = [security_group['GroupId']]

    #
    # Bitbucket
    #

    if (not method) or (method == "bitbucket"):
        project_yaml['bitbucket'] = {}
        project_yaml['git'] = {}

        project_name = project['name']
        bitbucket_user = project['bitbucket']['user']
        bitbucket_token = project['bitbucket']['token']
        auth = HTTPBasicAuth(bitbucket_user, bitbucket_token)
        ssh_pub_key = local("ssh-keygen -f salt/root/web/files/web.pem -y", capture=True)
        repo_url = "git@bitbucket.org:"+bitbucket_user+"/"+project_name+".git"

        req = requests.get('https://api.bitbucket.org/2.0/repositories/'+bitbucket_user+'/'+project_name, auth=auth)

        if req.status_code == 404:
            data = {
                'scm': 'git',
                'owner': bitbucket_user,
                'repo_slug': project_name,
                'is_private': True
            }
            req = requests.post('https://api.bitbucket.org/2.0/repositories/'+bitbucket_user+'/'+project_name, data=data, auth=auth)
            pprint.pprint(req.json())

        req = requests.get('https://bitbucket.org/api/1.0/repositories/'+bitbucket_user+'/'+project_name+'/deploy-keys', auth=auth)

        if req.status_code == 200:
            data = {
                'accountname': bitbucket_user,
                'repo_slug': project_name,
                'label': project_name,
                'key': ssh_pub_key
            }
            req = requests.post('https://bitbucket.org/api/1.0/repositories/'+bitbucket_user+'/'+project_name+'/deploy-keys', data=data, auth=auth)
            project_yaml['bitbucket']['deploy_key_id'] = req.json()['pk']
            pprint.pprint(req.json())

        with settings(warn_only=True):
            has_git_dir = local("test -d .git", capture=True)
            if has_git_dir.return_code != "0":
                local("git init")

        git_remotes = local("git remote", capture=True)
        if "origin" not in git_remotes:
            local("git remote add origin "+repo_url)
        else:
            local("git remote set-url origin "+repo_url)

        project_yaml['git']['repo'] = repo_url

    #
    # Update YAML
    #

    new_project_yaml = ruamel.yaml.dump(project_yaml, Dumper=ruamel.yaml.RoundTripDumper)

    with open('project.conf', 'w') as project_file:
        project_file.write(new_project_yaml)


@task
@hosts('localhost')
def clean(method=False):

    if (not method) or (method == "aws"):

        #
        # AWS
        #

        local("aws ec2 delete-key-pair --key-name "+project['name'], capture=True)

        if project['aws']['address_allocation_id']:
            local("aws ec2 release-address --allocation-id "+project['aws']['address_allocation_id'], capture=True)

        vpc_id = project['aws']['vpc_id']

        security_groups = local("aws ec2 describe-security-groups --filters Name=vpc-id,Values="+vpc_id+" --output json --query 'SecurityGroups[]'", capture=True)
        if security_groups != "": 
            for security_group in json.loads(security_groups):
                print security_group
                if security_group['GroupName'] != 'default':
                    local("aws ec2 delete-security-group --group-id "+security_group['GroupId'], capture=True)
        else:
            print "No SecurityGroups"

        internet_gateways = local("aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values="+vpc_id+" --output json --query 'InternetGateways[]'", capture=True)
        if internet_gateways != "": 
            for internet_gateway in json.loads(internet_gateways):
                print internet_gateway
                for attachment in internet_gateway['Attachments']:
                    print attachment
                    local("aws ec2 detach-internet-gateway --internet-gateway-id "+internet_gateway['InternetGatewayId']+" --vpc-id "+attachment['VpcId'])
                    local("aws ec2 delete-internet-gateway --internet-gateway-id "+internet_gateway['InternetGatewayId'])
        else:
            print "No InternetGateways"

        subnets = local("aws ec2 describe-subnets --filters Name=vpc-id,Values="+vpc_id+" --output json --query 'Subnets[]'", capture=True)
        if subnets != "":
            for subnet in json.loads(subnets):
                print subnet
                local("aws ec2 delete-subnet --subnet-id "+subnet['SubnetId'])
        else:
            print "No Subnets"

        route_tables = local("aws ec2 describe-route-tables --filters Name=vpc-id,Values="+vpc_id+" --output json --query 'RouteTables[]'", capture=True)
        if route_tables != "":
            for route_table in json.loads(route_tables):
                print route_table
                if len(route_table['Associations']) < 1:
                    local("aws ec2 delete-route-table --route-table-id "+route_table['RouteTableId'])
        else:
            print "No RouteTables"

        vpc = local("aws ec2 describe-vpcs --filters Name=vpc-id,Values="+vpc_id+" --output json --query 'Vpcs[]'", capture=True)
        if vpc != "":
            local("aws ec2 delete-vpc --vpc-id "+vpc_id)
        else:
            print "No Vpc"

        project_yaml.pop('aws', None)

    if (not method) or (method == "bitbucket"):
        #
        # Bitbucket
        #

        project_name = project['name']
        bitbucket_user = project['bitbucket']['user']
        bitbucket_token = project['bitbucket']['token']
        bitbucket_deploy_key_id = str(project['bitbucket']['deploy_key_id'])
        auth = HTTPBasicAuth(bitbucket_user, bitbucket_token)

        req = requests.get('https://api.bitbucket.org/2.0/repositories/'+bitbucket_user+'/'+project_name, auth=auth)

        if req.status_code == 200:
            data = { 'accountname': bitbucket_user, 'repo_slug': project_name, 'pk': bitbucket_deploy_key_id }
            req = requests.delete('https://api.bitbucket.org/1.0/repositories/'+bitbucket_user+'/'+project_name+'/deploy-keys/'+bitbucket_deploy_key_id, data=data, auth=auth)

            if req.status_code == 204:
                project_yaml['bitbucket'].pop('deploy_key_id', None)

        with settings(warn_only=True):
            local("git remote set-url origin git@github.com:stackstrap/craft-ops.git")


    #
    # Full clean
    #

    if (not method):
        local("rm -f salt/root/web/files/web.pem")
        local("rm -f salt/root/web/files/web.pub")
        local("rm -f salt/root/dev/files/web.pem")
        local("rm -f salt/root/dev/files/web.pub")
        local("cat /dev/null > salt/root/web/files/authorized_keys")

        project_yaml.pop('web', None)
        project_yaml.pop('bitbucket', None)
        project_yaml.pop('git', None)


    #
    # Update YAML
    #

    new_project_yaml = ruamel.yaml.dump(project_yaml, Dumper=ruamel.yaml.RoundTripDumper)

    with open('project.conf', 'w') as project_file:
        project_file.write(new_project_yaml)


@task
def find(query=""):
    local("ack "+query+" --ignore-dir=craft/plugins --ignore-dir=craft/storage --ignore-dir=.vagrant --ignore-dir=vendor --ignore-dir=.git")


@task
def tree():
    local("tree -a -I 'vendor|.git|storage|plugins|.vagrant'")


@task
def provision(): 
    local("sudo salt-call state.highstate pillar='"+json.dumps(project)+"' -l debug")
