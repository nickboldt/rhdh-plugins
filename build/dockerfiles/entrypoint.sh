#
# Copyright (c) 2023 Red Hat, Inc.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

if ! whoami &> /dev/null; then
  if [ -w /etc/passwd ]; then
    echo "${USER_NAME:-jboss}:x:$(id -u):0:${USER_NAME:-jboss} user:${HOME}:/sbin/nologin" >> /etc/passwd
  fi
  # shellcheck disable=SC2086
  chown -R ${USER_NAME:-jboss}:${USER_NAME:-jboss} /var/www/html
  chmod -R g+rw /var/www/html
fi

set -x

# start httpd
if [[ -x /usr/sbin/httpd ]]; then
  /usr/sbin/httpd -D FOREGROUND
elif [[ -x /usr/bin/run-httpd ]]; then
  /usr/bin/run-httpd
fi
