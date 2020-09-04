# prérequis
sudo apt install -y xvfb libxrender1 libxtst6
curl https://processing.org/download/install-arm.sh | sudo sh

# execution
xvfb-run processing-java --sketch=SquiggleDraw/SquiggleDraw --run MyPhoto.jpg

