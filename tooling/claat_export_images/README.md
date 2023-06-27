# CLAAT Image exporter, Dart version

A tool to export the images for a CLAAT codelab.

## Install dependencies

```shell
dart pub get
```

## Enabling API Access

Follow the instructions in the Python Quickstart section on [setting up your environment][].
You will wind up with a client secret JSON file that this script requires to work.

  [setting up your environment]: https://developers.google.com/docs/api/quickstart/python#set_up_your_environment
 

## Run

After following the quickstart setup instructions, run the code:

```shell
dart bin/claat_export_images.dart -s client_secret.json -d 1389diNFkkLUQUVIpJ1B2XGdk8wfsPNJOGeVYZWlEhpk
```