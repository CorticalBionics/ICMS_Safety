#%% Pitt Extraction Script
import os
import shutil
tld = r"P:\data_raw\human\crs_array"
export_path = r"P:\users\tgh28\Experiments\Longitudinal_ICMS\vm_data"
bson2json = r"C:\git\climber\src\VoltageMonitor\utilities\bson2json\bson2json.exe"
subject_list = ['CRS02b', 'CRS07', 'CRS08']

#%% List all voltage monitor files
for s in subject_list:
    vm_path = os.path.join(tld, s, 'VoltageMonitorDB')
    flist = os.listdir(vm_path)
    for f in flist:
        # Skip not folders
        if not os.path.isdir(os.path.join(vm_path, f)):
            continue
        # Skip folders without vm dbs
        ffpath = os.path.join(vm_path, f, 'voltage_monitor_db')
        if not os.path.isdir(ffpath):
            continue
        # Find bson.gz
        fflist = os.listdir(ffpath)
        bson_gz_fname = [f for f in fflist if f.endswith('.bson.gz')]
        if not len(bson_gz_fname) == 1:
            continue
        bson_gz_fname = bson_gz_fname[0]
        # Convert to json and export
        output_json_fname = os.path.join(export_path, bson_gz_fname[:-8])
        if os.path.exists(output_json_fname):
            continue
        print(f"converting {bson_gz_fname}")
        cmd = bson2json + ' --out' + output_json_fname + ' ' + os.path.join(ffpath, bson_gz_fname)
        os.system('cmd /c' + cmd)
        break
    break


#%% Chicago version
import os
import climber_core_utilities as ccu
from typing import cast

tld = cast(str, ccu.load_config.system('backup_path'))
bson2json = os.path.join(cast(str, os.getenv('STIMULATION_MODULES')) , r"legacy\VoltageMonitor\utilities\bson2json\bson2json.exe")
subject_list = ccu.load_config.participant().keys()
subject_list = [s for s in subject_list if s.startswith('BCI')]

#%% List all voltage monitor files
for s in subject_list:
    vm_path = os.path.join(tld, s, 'VoltageMonitor')
    folder_list = [f for f in os.listdir(vm_path) if f.startswith('VM_')]
    for f in folder_list:
        # print(f"Folder: {f}")
        ff = os.path.join(vm_path, f)
        # Skip not folders
        if not os.path.isdir(ff):
            print(f"\tNot a folder")
            continue

        # Find bson.gz
        fflist = os.listdir(ff)
        bson_gz_fname = [f for f in fflist if f.endswith('.bson.gz')]
        if not len(bson_gz_fname) == 1:
            continue
        bson_gz_fname = bson_gz_fname[0]

        # Convert to json and export
        output_json_fname = f"{os.path.join(ff, bson_gz_fname[:-8])}.json"
        if os.path.exists(output_json_fname):
            continue

        # Convert
        print(f"converting {bson_gz_fname}")
        cmd = bson2json + ' --out' + output_json_fname + ' ' + os.path.join(ff, bson_gz_fname)
        os.system('cmd /c' + cmd)