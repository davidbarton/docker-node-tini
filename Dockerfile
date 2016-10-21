FROM node:6.9

MAINTAINER David Barton <david.barton@posteo.de>

# Set versions and folders used
ENV TINI_VERSION='v0.10.0' \
  NPM_VERSION='v3.10' \
  USER_NAME='docker_user' \
  APP_FOLDER='docker_app'

# Add tini init, see https://github.com/krallin/tini
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini

# Fix bug https://github.com/npm/npm/issues/9863
RUN cd $(npm root -g)/npm \
  && npm install fs-extra \
  && sed -i -e s/graceful-fs/fs-extra/ -e s/fs\.rename/fs.move/ ./lib/utils/rename.js

# Stack these commands for cache/build speed
# Disable npm progress, it's faster
# Set npm registry, may be faster, see https://github.com/npm/npm/issues/8836
# Update npm for new features, do it quietly
# Create an unprivileged user, never use root
# Make tini executable
RUN npm config set progress false && \
  npm config set registry http://registry.npmjs.org/ && \
  npm install --global --quiet --depth 0 npm@${NPM_VERSION} && \
  useradd --user-group --create-home --shell /bin/false ${USER_NAME} && \
  chmod +x /tini

# Copy only necessary files now, it helps docker with layer caching
ONBUILD COPY package.json /home/${USER_NAME}/${APP_FOLDER}/

# Files copied with COPY are owned by root, change owner to user
ONBUILD RUN chown -R ${USER_NAME}:${USER_NAME} /home/${USER_NAME}/*

# Use our user from now
ONBUILD USER ${USER_NAME}

# Set workdir
ONBUILD WORKDIR /home/${USER_NAME}/${APP_FOLDER}

# Install npm dependencies
ONBUILD RUN npm install --quiet --depth 0

# Copy all app files now
ONBUILD USER root
ONBUILD COPY . /home/${USER_NAME}/${APP_FOLDER}/
ONBUILD RUN chown -R ${USER_NAME}:${USER_NAME} /home/${USER_NAME}/*
ONBUILD USER ${USER_NAME}

# Set tini as entrypoint
ENTRYPOINT ["/tini", "--"]

# Run node app
CMD [ "npm", "start" ]
