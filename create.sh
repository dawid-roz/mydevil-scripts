#!/bin/bash

export LC_ALL=C

# Skrypt tworzy nowy projekt na kdevserver2:
# - Sprawdza, czy podano nazwę projektu jako pierwszy parametr
# - Generuje hasło spełniające wymagania (min. 6 znaków, 1 cyfra, 1 mała, 1 duża litera)
# - Dodaje domenę i bazę danych przy użyciu poleceń devil
# - Klonuje repozytorium do właściwego katalogu
# - Konfiguruje katalog public_html i instaluje zależności composera
# - Tworzy plik .env.local z odpowiednimi zmiennymi środowiskowymi

# Sprawdzenie, czy podano nazwę projektu
if [ -z "$1" ]; then
  echo "Użycie: $0 <nazwa_projektu>"
  exit 1
fi

projektName="$1"

# Generowanie hasła:
# Wymagania: min. 6 znaków, co najmniej jedna cyfra, jedna mała litera, jedna duża litera.
lower=$(tr -dc 'a-z' </dev/urandom | head -c1)
upper=$(tr -dc 'A-Z' </dev/urandom | head -c1)
digit=$(tr -dc '0-9' </dev/urandom | head -c1)
rest=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c5)
hasloBazyDanych=$(echo "${lower}${upper}${digit}${rest}" | fold -w1 | gshuf | tr -d '\n')

echo "Wygenerowane hasło: ${hasloBazyDanych}"

# Dodanie domeny:
devil www add "${projektName}.kdevserver2.usermd.net"

devil www options "${projectName}.kdevserver2.usermd.net" php_openbasedir "/usr/home/kdevserver2/domains/${projectName}.kdevserver2.usermd.net:/tmp:/usr/share:/usr/local/share:/dev"

# Dodanie bazy danych - hasło podawane dwukrotnie przez stdin

echo "Za chwile wpisz wygenerowane wczesniej haslo" 

devil mysql db add "${projektName}" "${projektName}"


# Klonowanie projektu z repozytorium

repoUrl="git@github.com:Kdevelopmentltd/man-backend.git"
targetDir="/home/kdevserver2/domains/${projektName}.kdevserver2.usermd.net"
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
php80 ../../composer/composer install
php80 bin/console doctrine:migrations:migrate


# Generowanie pliku .env.local
cat <<EOF > .env.local
DATABASE_URL=mysql://m1048_${projektName}:${hasloBazyDanych}@mysql66.mydevil.net:3306/m1048_${projektName}
SMSAPI_TOKEN='1111'
APP_ENV=dev
APP_SECRET=1111
CORS_ALLOW_ORIGIN='^https?://(localhost|127\.0\.0\.1)(:[0-9]+)?$'
METADATA='1111'
APP_DEBUG=1
LOCATION_VALIDATION_ENABLED=0
FRONTEND_BASE_URL='https://${projektName}.netlify.app/'
MESSENGER_TRANSPORT_DSN=doctrine://default?auto_setup=0
EOF

echo "Skrypt zakończył działanie pomyślnie."
