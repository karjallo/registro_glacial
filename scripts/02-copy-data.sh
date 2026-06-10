# para poder realizar la carga de los archivos csv, es necesario que el usuario
# postgres tenga acceso a la carpeta en la que se encuentran, por tal razon,
# creamos una carpeta y le damos permisos, copiamos los datos alli primeramente
sudo mkdir -p /var/local/db_imports/data/

sudo chown -R $(whoami):postgres /var/local/db_imports/

# la notacion numerica para permisos corresponde a
# r = 4, w = 2, x = 1, ninguno = 0, y el orden
# 1ro = owner, 2do=group, 3ro=others
sudo chmod 750 /var/local/db_imports/
sudo chmod 750 /var/local/db_imports/data/

sudo cp ~/projects/registro_glacial/data/*.csv /var/local/db_imports/data/
sudo chown -R karjallo:postgres /var/local/db_imports/
sudo chmod 640 /var/local/db_imports/data/*.csv
