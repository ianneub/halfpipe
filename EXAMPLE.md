# Example halfpipe.yml

```yaml
---
# this is a theoretical example of how we might use a yaml file to describe a CD process for a Rails app

# image is the base docker image to be used and will be the basis for all further actions
image: ianneub/dind
volumes:
  - "/var/lib/docker" # define volumes that will be saved between each step in the pipeline
  # - "/data" will always be assumed

# this pipeline must run in docker privileged mode, so that it can run its own docker env
privileged: true

# this is the name of the target image
name: rails_web

# these variables will be made available in all steps of the pipeline
environment:
  WEB_SERVICE: web1
  CLOCK_SERVICE: clock1
  WORKER_SERVICE: worker1
  # CI will be set to 'true'
  # COMMIT_SHA1 will be set to the sha1 of the commit
  # COMMIT_AUTHOR will be set to the git commiter. ie: The Most Interesting Programmer <first2prod@ftw.com>
  # NAME will be set to whatever is in the "name" yaml config option, or the name of the repo

# The "run" section is the pipeline through which the code will be built, tested, deployed, or any other steps that might be needed.
run:
  # This step will create a container to be used by other steps
  - name: build
    shell:
      - docker build -f Dockerfile.dev -t rails_web:latest .

  # This step will test the container by running it along with other containers
  - name: test
    autostart: true # default; auto run this task if the previous task is successful
    shell:
      - make test # requires make and docker-compose
    notify: # the notify section will setup optional notifications for this step based on the "notify" section in the root config
      success: 
        - devs
      fail:
        - devs
        - commiter

  - name: Create production container
    shell:
      - docker build -f Dockerfile.production -t $NAME:$COMMIT_SHA1 .
    notify:
      fail:
        - devs
        - ops

  - name: Deploy staging
    autostart: false # the build system will stop here and not run any more until it is explicitly started
    shell:
      - docker push $NAME:$COMMIT_SHA1
      - tutum stack create ...
    notify:
      success:
        - commiter
      fail:
        - ops

  # 2+ consecutive steps with autostart == false will be shown in the UI side by side. Letting the user jump to any of the steps.
  - name: Deploy production
    autostart: false # do not automatically deploy, if true and "test" step is successful, then this will be executed automatically. otherwise, it will require a user to execute.
    shell:
      - docker push $NAME:$COMMIT_SHA1
      - tutum service stop $CLOCK_SERVICE # stop clock and somehow wait
      - while tutum service $CLOCK_SERVICE != stopped; sleep 3; # pseudo code
      - while <devops-web api> running workers != 0; sleep 5;
      - tutum service stop $WORKER_SERVICE # stop workers and somehow wait
      - while tutum service $WORKER_SERVICE != stopped; sleep 3;
      - tutum service set --redeploy --image $NAME:$COMMIT_SHA1 $WEB_SERVICE # web
      - tutum service set --redeploy --image $NAME:$COMMIT_SHA1 $WORKER_SERVICE # worker
      - tutum service set --redeploy --image $NAME:$COMMIT_SHA1 $CLOCK_SERVICE # clock
    notify:
      success:
        - devs
      fail:
        - ops
        - commiter
        - devs

# The notify section can be used to setup notifications for the various steps
notify:
  devs: # any label can be used here, this way you can setup multiple hipchat notifications for example
    hipchat:
      room: dev
      token: asdf
  ops:
    email:
      to:
        - ops4suckers@ftw.com
  commiter:
    email:
      to: 
        - $COMMIT_AUTHOR

# the shell section can be used to configure the shell work step in all the steps that use it
shell:
  pre: # this set of scripts will run before every step that uses the shell type worker
    - wrapdocker

# Example build run
# Given SHA: asdf
# docker run --name asdf_data -v /data -v /var/lib/docker busybox
# docker run -it --privileged --rm --volumes-from asdf_data ianneub/dind bash
  # wrapdocker
```
