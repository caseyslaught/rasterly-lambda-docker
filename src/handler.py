from osgeo import gdal
import rasterio


def handle():
    print(f'GDAL version: {gdal.VersionInfo()}')
    print(f'Rasterio version: {rasterio.__version__}')