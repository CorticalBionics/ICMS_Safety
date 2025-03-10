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