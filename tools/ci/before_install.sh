set -e

git clone https://github.com/ManageIQ/manageiq.git --depth 1 spec/manageiq
cd spec/manageiq

which bower || npm install -g bower
bower install --allow-root -F --config.analytics=false

echo "1" > REGION
cp certs/v2_key.dev certs/v2_key
cp config/database.pg.yml config/database.yml
cd -

echo "gem: --no-ri --no-rdoc --no-document" > ~/.gemrc
travis_retry gem install bundler -v ">= 1.11.1"

psql -c "CREATE USER root SUPERUSER PASSWORD 'smartvm';" -U postgres
export BUNDLE_WITHOUT=development
export BUNDLE_GEMFILE=${PWD}/Gemfile

set +v
