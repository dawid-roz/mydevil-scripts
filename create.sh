#!/bin/bash

export LC_ALL=C

# Definiowanie zmiennych konfiguracyjnych
serwerName="kdevserver2"
mysqlServer="mysql66"
mysqlPrefix="m1048"

# Sprawdzenie, czy podano nazwę projektu
if [ -z "$1" ]; then
  echo "Użycie: $0 <nazwa_projektu>"
  exit 1
fi

projektName="$1"

# Generowanie hasła:
lower=$(tr -dc 'a-z' </dev/urandom | head -c1)
upper=$(tr -dc 'A-Z' </dev/urandom | head -c1)
digit=$(tr -dc '0-9' </dev/urandom | head -c1)
rest=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c5)
hasloBazyDanych=$(echo "${lower}${upper}${digit}${rest}" | fold -w1 | gshuf | tr -d '\n')

echo "Wygenerowane hasło: ${hasloBazyDanych}"

# Dodanie domeny
devil www add "${projektName}.${serwerName}.usermd.net"

devil www options "${projektName}.${serwerName}.usermd.net" php_openbasedir "/usr/home/${serwerName}/domains/${projektName}.${serwerName}.usermd.net:/tmp:/usr/share:/usr/local/share:/dev"

# Dodanie bazy danych
echo "\n\n"
echo "Za chwilę wpisz wygenerowane wcześniej hasło"

devil mysql db add "${projektName}" "${projektName}"

# Klonowanie projektu z repozytorium
repoUrl="git@github.com:Kdevelopmentltd/man-backend.git"
targetDir="/home/${serwerName}/domains/${projektName}.${serwerName}.usermd.net"
tempDir="${targetDir}/repo_temp"
shopt -s dotglob

git clone "${repoUrl}" "${tempDir}" || { echo "Błąd klonowania repozytorium"; exit 1; }

mv "${tempDir}/"* "${targetDir}/" || { echo "Błąd przenoszenia plików"; exit 1; }
shopt -u dotglob
rmdir "${tempDir}"

# Przejście do katalogu projektu
cd "${targetDir}" || { echo "Nie można przejść do katalogu ${targetDir}"; exit 1; }

# Konfiguracja katalogów i instalacja zależności
rm -rf public_html
ln -s public public_html

# Generowanie pliku .env.local
cat <<EOF > .env.local
DATABASE_URL=mysql://${mysqlPrefix}_${projektName}:${hasloBazyDanych}@${mysqlServer}.mydevil.net:3306/${mysqlPrefix}_${projektName}
SMSAPI_TOKEN='1111'
APP_ENV=dev
APP_SECRET=1111
CORS_ALLOW_ORIGIN='^https?://(localhost|127\\.0\\.0\\.1)(:[0-9]+)?$'
METADATA='1111'
APP_DEBUG=1
LOCATION_VALIDATION_ENABLED=0
FRONTEND_BASE_URL='https://${projektName}.netlify.app/'
MESSENGER_TRANSPORT_DSN=doctrine://default?auto_setup=0
EOF

php80 ../../composer/composer install
php80 bin/console doctrine:migrations:migrate
