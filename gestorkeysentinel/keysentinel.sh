#!/bin/bash

#Colours
greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
purpleColour="\e[0;35m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
grayColour="\e[0;37m\033[1m"

function ctrl_c (){
  echo -e "\n\n${redColour}[!] Saliendo...${endColour}\n"
  tput cnorm && exit 1
}

# Ctrl+C
trap ctrl_c INT

master_key_services=""

# Validación de clave  
function validate_master_key(){
  gpg --batch --yes --passphrase "$master_key" -d .log.gpg &>/dev/null
}

# Indicadores
declare -i parameter_counter=0
do_initial=true

while getopts "acrlhq" arg; do  
  do_initial=false 
  case $arg in 
    a) let parameter_counter+=1;;
    c) let parameter_counter+=2;;
    r) let parameter_counter+=3;;
    l) let parameter_counter+=4;;
    h) ;;
    q) let parameter_counter+=5;;
  esac
done

# Condicionales para crear clave con validación y archivos correspondiente (.log.gpg/.session.time)
if [ ! -f .log.gpg ]; then
  tput cnorm
  echo -ne "\n${yellowColour}[+] Crea tu clave para abrir ${endColour}${greenColour}KeySentinel${endColour}${yellowColour}: ${endColour}"
  read -s master_key
  echo "" 
  tput civis
  echo -e "\n${yellowColour}[+]${endColour}${grayColour} Guardando Clave...${endColour}"
  touch .log.gpg 
  start_time=$(date +%s)
  echo "$start_time" > .session.time
  echo "$master_key" | gpg --batch --yes --passphrase "$master_key" -c -o .log.gpg &>/dev/null
  sleep 1.2
fi
  if validate_master_key; then
    echo -e "\n${yellowColour}[+]${endColour}${greenColour} Iniciando KeySentinel...${endColour}"
    sleep 1
  else
    tput civis
    echo -e "\n${yellowColour}[+]${endColour}${greenColour} Iniciando KeySentinel...${endColour}"
    sleep 1
    tput cnorm
  fi 
if [ -f .session.time ]; then
  previous_time=$(cat .session.time)
  current_time=$(date +%s)
  diff=$((current_time - previous_time))
  if [ "$diff" -gt 300 ]; then
    echo -e "${yellowColour}[!] Sesión expirada.${endColour}"
    echo -ne "\n${yellowColour}[+] Introduce tu clave para abrir ${endColour}${greenColour}KeySentinel${endColour}${yellowColour}: ${endColour}"
    read -s master_key
    echo ""
    tput civis
    if ! validate_master_key; then
      echo -e "${redColour}[!] Clave incorrecta. Saliendo...${endColour}"
      tput cnorm
      exit 1
    else 
      echo -e "${greenColour}[+] Clave correcta.${endColour}"
    fi
    new_time=$(date +%s)
    echo "$new_time" > .session.time
  fi
fi
tput cnorm

# Agregar nueva contraseña
function AddPass(){
  echo -ne "\n${yellowColour}[+]${endColour}${grayColour} Plataforma: ${endColour}"
  read plataforma

  echo -ne "\n${yellowColour}[+]${endColour}${grayColour} Email: ${endColour}"
  read email 

  echo -ne "\n${yellowColour}[+]${endColour}${grayColour} Contraseña del servicio: ${endColour}"
  read -s servicio_pass
  echo ""

  if [ ! -f .logpass.gpg ]; then
    echo -ne "\n${yellowColour}[+] Elige la clave con la que se van a cifrar todos tus servicios: ${endColour}"
    read -s master_key_services
    echo ""

    tput civis
    echo "$plataforma|$email|$servicio_pass" > temp_file
    gpg --batch --yes --passphrase "$master_key_services" -c -o .logpass.gpg temp_file &>/dev/null
    rm -f temp_file
    echo -e "\n${greenColour}[+] Servicio agregado correctamente${endColour}"
    tput cnorm
    return
  fi

  echo -ne "\n${yellowColour}[+] Introduce tu clave para cifrar los servicios: ${endColour}"
  read -s master_key_services
  echo ""

  tput civis
  gpg --batch --yes --passphrase "$master_key_services" -d .logpass.gpg 2>/dev/null > temp_file

  if [ $? -ne 0 ]; then
    echo -e "\n${redColour}[!] Clave incorrecta. Saliendo...${endColour}"
    rm -f temp_file
    return 1
  fi

  echo "$plataforma|$email|$servicio_pass" >> temp_file
  gpg --batch --yes --passphrase "$master_key_services" -c -o .logpass.gpg temp_file &>/dev/null
  rm -f temp_file

  echo -e "\n${greenColour}[+] Servicio agregado correctamente.${endColour}"
  tput cnorm
}


# Consultar contraseña
function ConsultPass(){
  if [ ! -f .logpass.gpg ]; then
    echo -e "\n${redColour}[!] No hay contraseñas guardadas.${endColour}"
    return 1
  fi

  echo -ne "\n${yellowColour}[+]${endColour}${grayColour} Introduce tu clave para descifrar el servicio: ${endColour}"
  read -s master_key_services
  echo ""

  tput civis
  gpg --batch --yes --passphrase "$master_key_services" -d .logpass.gpg 2>/dev/null > temp_file

  if [ $? -ne 0 ]; then
    echo -e "\n${redColour}[!] Clave incorrecta.${endColour}"
    rm -f temp_file
    tput cnorm
    return 1
  fi

  if ! grep -q '.' temp_file; then
    echo -e "\n${redColour}[!] No hay servicios guardados.${endColour}"
    rm -f temp_file
    tput cnorm
    return 1
  fi

  tput cnorm
  echo -ne "\n${yellowColour}[+]${endColour}${grayColour} ¿Qué servicio deseas consultar? -> ${endColour}"
  read service_to_find

  echo -ne "\n${yellowColour}[+]${endColour}${grayColour} ¿Cuál es el email del servicio${endColour} ${purpleColour}$service_to_find${endColour}${grayColour}? -> ${endColour}"
  read service_to_find_email

  tput civis
  match=$(grep -iE "^${service_to_find}\|${service_to_find_email}\|" temp_file)

  if [[ -n "$match" ]]; then
    plat=$(echo "$match" | cut -d '|' -f1)
    pass=$(echo "$match" | cut -d '|' -f3)

    echo -e "\n${yellowColour}[+]${endColour}${grayColour} Buscando servicio...${endColour}"
    sleep 1
    echo -e "\n${yellowColour}[+]${endColour}${grayColour} Servicio encontrado:${endColour} ${purpleColour}$plat${endColour}"
    echo -e "\n${yellowColour}[*]${endColour}${grayColour} Contraseña:${endColour} ${greenColour}$pass${endColour}"
  else
   echo -e "\n${redColour}[!] El servicio${endColour} ${purpleColour}'$service_to_find'${endColour} ${redColour}con el email${endColour} ${purpleColour}'$service_to_find_email'${endColour}${redColour} no está registrado en la base de datos.${endColour}"
  fi

  rm -f temp_file
  tput cnorm
}

# Eliminar un servicio
function RemovePass(){
  if [ ! -f .logpass.gpg ]; then
    echo -e "\n${redColour}[!] No hay servicios guardados.${endColour}"
    return 1
  fi

  echo -ne "\n${yellowColour}[+]${endColour}${grayColour} Introduce tu clave para descifrar los servicios: ${endColour}"
  read -s master_key
  echo ""

  tput civis
  gpg --batch --yes --passphrase "$master_key" -d .logpass.gpg 2>/dev/null > temp_file

  if [ $? -ne 0 ]; then
    echo -e "\n${redColour}[!] Clave incorrecta.${endColour}"
    rm -f temp_file
    tput cnorm
    return 1
  fi

  if ! grep -q '.' temp_file; then
    echo -e "\n${redColour}[!] No hay servicios guardados.${endColour}"
    rm -f temp_file
    tput cnorm
    return 1
  fi

  tput cnorm
  echo -ne "\n${yellowColour}[+]${endColour}${grayColour} ¿Qué servicio deseas eliminar? -> ${endColour}"
  read service_to_delete

  echo -ne "\n${yellowColour}[+]${endColour}${grayColour} ¿Cuál es el email del servicio que deseas eliminar? -> ${endColour}"
  read service_to_delete_email

  delete_pattern="^${service_to_delete}\|${service_to_delete_email}\|"

  if ! grep -iqE "$delete_pattern" temp_file; then
    echo -e "\n${redColour}[!] El servicio${endColour} ${purpleColour}'$service_to_delete'${endColour} ${redColour}con el email${endColour} ${purpleColour}'$service_to_delete_email'${endColour}${redColour} no está registrado en la base de datos.${endColour}"
    rm -f temp_file
    tput cnorm
    return 1
  fi

  echo -ne "\n${yellowColour}[?]${endColour}${grayColour} ¿Estás seguro de eliminar${endColour} ${purpleColour}'$service_to_delete'${endColour}${grayColour} con el email${endColour} ${purpleColour}'$service_to_delete_email'${endColour}${grayColour}?${endColour} ${grayColour}(s/n): ${endColour}"
  read confirm

  tput civis
  if [[ "$confirm" != "s" ]]; then
    echo -e "${blueColour}[!] Cancelado.${endColour}"
    rm -f temp_file
    tput cnorm
    return 0
  fi

  echo -e "\n${yellowColour}[+] Eliminando servicio...${endColour}"
  sleep 1

  grep -ivE "$delete_pattern" temp_file > temp_cleaned
  mv temp_cleaned temp_file

  gpg --batch --yes --passphrase "$master_key" -c -o .logpass.gpg temp_file &>/dev/null
  rm -f temp_file

  echo -e "\n${greenColour}[+] Servicio eliminado correctamente.${endColour}"
  tput cnorm
}

# Listar servicios agregados
function ListServices(){
  if [ ! -f .logpass.gpg ]; then
    echo -e "\n${redColour}[!] No hay servicios guardados.${endColour}"
    return 1
  fi

  echo -ne "\n${yellowColour}[+]${endColour}${grayColour} Introduce tu clave para descifrar los servicios: ${endColour}"
  read -s master_key
  echo ""

  tput civis
  gpg --batch --yes --passphrase "$master_key" -d .logpass.gpg 2>/dev/null > temp_file

  if [ $? -ne 0 ]; then
    echo -e "\n${redColour}[!] Clave incorrecta.${endColour}"
    rm -f temp_file
    tput cnorm
    return 1
  fi

  if ! grep -q '.' temp_file; then
    echo -e "\n${redColour}[!] No hay servicios guardados.${endColour}"
    rm -f temp_file
    tput cnorm
    return 1
  fi

  echo -e "\n${yellowColour}[+]${endColour}${grayColour} Lista de credenciales guardadas:${endColour}\n"
  printf "${yellowColour}%-15s | %-25s | %-20s${endColour}\n" "Plataforma" "Email" "Contraseña"
  printf "${grayColour}%.70s${endColour}\n" "----------------------------------------------------------------------"

  while IFS='|' read -r plat mail pass; do 
    secret=$(printf '%*s' "${#pass}" '' | tr ' ' '*')
    [[ -z "$plat" || -z "$mail" || -z "$secret" ]] && continue

    printf "${grayColour}%-15s | %-25s | %-20s${endColour}\n" "$plat" "$mail" "$secret"
  done < temp_file

  sleep 1
  tput cnorm
  echo -ne "\n\n${yellowColour}[?]${endColour}${grayColour} ¿Deseas consultar la contraseña de algún servicio? (s/n): ${endColour}"
  read confirm

  if [[ "$confirm" != "s" ]]; then
    tput civis
    echo -e "${blueColour}[!] Cancelado.${endColour}"
    rm -f temp_file
    tput cnorm
    return 0
  fi

  echo -ne "\n${yellowColour}[+]${endColour}${grayColour} ¿Qué servicio deseas consultar? -> ${endColour}"
  read service_to_find

  echo -ne "\n${yellowColour}[+]${endColour}${grayColour} ¿Cuál es el email del servicio${endColour} ${purpleColour}$service_to_find${endColour}${grayColour}? -> ${endColour}"
  read service_to_find_email

  tput civis
  match=$(grep -iE "^${service_to_find}\|${service_to_find_email}\|" temp_file)

  if [[ -n "$match" ]]; then
    plat=$(echo "$match" | cut -d '|' -f1)
    pass=$(echo "$match" | cut -d '|' -f3)

    echo -e "\n${yellowColour}[+]${endColour}${grayColour} Buscando servicio...${endColour}"
    sleep 1
    echo -e "\n${yellowColour}[+]${endColour}${grayColour} Servicio encontrado:${endColour} ${purpleColour}$plat${endColour}"
    echo -e "\n${yellowColour}[*]${endColour}${grayColour} Contraseña:${endColour} ${greenColour}$pass${endColour}"
  else
    echo -e "\n${redColour}[!] El servicio${endColour} ${purpleColour}'$service_to_find'${endColour} ${redColour}con el email${endColour} ${purpleColour}'$service_to_find_email'${endColour}${redColour} no está registrado en la base de datos.${endColour}"
  fi

  rm -f temp_file
  tput cnorm
}

# Panel de funciones
function helPanel(){
  echo -e "\n${yellowColour}[+]${endColour}${grayColour} Uso:${endColour}${greenColour} $0${endColour}\n"
  echo -e "\t${blueColour}[-a]${endColour}${grayColour} Agregar contraseña nueva${endColour}"
  echo -e "\t${blueColour}[-c]${endColour}${grayColour} Consultar una contraseña${endColour}"
  echo -e "\t${blueColour}[-r]${endColour}${grayColour} Eliminar una contraseña${endColour}"
  echo -e "\t${blueColour}[-l]${endColour}${grayColour} Listar todos los servicios guardados${endColour}"
  echo -e "\t${blueColour}[-h]${endColour}${grayColour} Llamar a este panel de ayuda${endColour}"
}

  if [ $parameter_counter -eq 1 ]; then
    AddPass 
  elif [ $parameter_counter -eq 2 ]; then
    ConsultPass 
  elif [ $parameter_counter -eq 3 ]; then
    RemovePass 
  elif [ $parameter_counter -eq 4 ]; then
    ListServices
  else 
    helPanel
  fi
