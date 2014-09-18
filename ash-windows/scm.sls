{% from "ash-windows/map.jinja" import ash with context %}

include:
{% if ash.install_emet and ash.emet_version in salt['pkg.list_available']('Emet') %}
  - ash-windows.emet
{% endif %}
  - ash-windows.mss

Create SCM Log Directory:
  cmd:
    - run
    - name: 'md "{{ ash.common_logdir }}" -Force'
    - shell: powershell
    - require: 
      - cmd: 'Expose MSS Settings'

#Apply Security Template
Apply Security Template:
  cmd:
    - run
    - name: 'start /wait Tools\Apply_LGPO_Delta.exe {{ ash.os_path }}{{ ash.role_path }}\GptTmpl.inf /log "{{ ash.common_logdir }}\{{ ash.os_path }}{{ ash.role_path }}-gpttmpl.log" /error "{{ ash.common_logdir }}\{{ ash.os_path }}{{ ash.role_path }}-gpttmpl.err"'
    - cwd: {{ ash.scm_cwd }}
    - require: 
      - cmd: 'Create SCM Log Directory'

#Apply Computer Configuration
Apply Computer Configuration:
  cmd:
    - run
    - name: 'start /wait Tools\ImportRegPol.exe /m {{ ash.os_path }}{{ ash.role_path }}\machine_registry.pol /log "{{ ash.common_logdir }}\{{ ash.os_path }}{{ ash.role_path }}MachineSettings.log" /error "{{ ash.common_logdir }}\{{ ash.os_path }}{{ ash.role_path }}MachineSettings.err"'
    - cwd: {{ ash.scm_cwd }}
    - require: 
      - cmd: 'Apply Security Template'

#Apply User Configuration
Apply User Configuration:
  cmd:
    - run
    - name: 'start /wait Tools\ImportRegPol.exe /m {{ ash.os_path }}{{ ash.role_path }}\user_registry.pol /log "{{ ash.common_logdir }}\{{ ash.os_path }}{{ ash.role_path }}UserSettings.log" /error "{{ ash.common_logdir }}\{{ ash.os_path }}{{ ash.role_path }}UserSettings.err"'
    - cwd: {{ ash.scm_cwd }}
    - require: 
      - cmd: 'Apply Computer Configuration'

#Apply Internet Explorer Machine Policy
Apply Internet Explorer Machine Policy:
  cmd:
    - run
    - name: 'start /wait Tools\ImportRegPol.exe /m {{ ash.ie_path }}\machine_registry.pol /log "{{ ash.common_logdir }}\IEMachineSettings.log" /error "{{ ash.common_logdir }}\IEMachineSettings.err"'
    - cwd: {{ ash.scm_cwd }}
    - require: 
      - cmd: 'Apply User Configuration'

#Apply Internet Explorer User Policy
Apply Internet Explorer User Policy:
  cmd:
    - run
    - name: 'start /wait Tools\ImportRegPol.exe /u {{ ash.ie_path }}\user_registry.pol /log "{{ ash.common_logdir }}\IEUserSettings.log" /error "{{ ash.common_logdir }}\IEUserSettings.err"'
    - cwd: {{ ash.scm_cwd }}
    - require: 
      - cmd: 'Apply Internet Explorer Machine Policy'

#Apply Audit Policy
Create Directory for Audit.csv:
  cmd:
    - run
    - name: 'md "{{ ash.win_audit_dir }}" -Force'
    - shell: powershell
    - require: 
      - cmd: 'Apply Internet Explorer User Policy'
Manage SCM Audit.csv:
  file:
    - managed
    - name: {{ ash.win_audit_file_name }}
    - source: {{ ash.scm_audit_file_source }}
    - require: 
      - cmd: 'Create Directory for Audit.csv'
Clear Audit Policy:
  cmd:
    - run
    - name: auditpol /clear /y
    - require: 
      - file: 'Manage SCM Audit.csv'
Apply Audit Policy:
  cmd:
    - run
    - name: auditpol /restore /file:"{{ ash.win_audit_file_name }}"
    - require: 
      - cmd: 'Clear Audit Policy'

#Copy Custom Administrative Template for Pass the Hash mitigations
PtH.admx:
  file:
    - managed
    - name: {{ ash.scm_pth_admx_name }}
    - source: {{ ash.scm_pth_admx_source }}
    - require: 
      - cmd: 'Apply Audit Policy'

PtH.adml:
  file:
    - managed
    - name: {{ ash.scm_pth_adml_name }}
    - source: {{ ash.scm_pth_adml_source }}
    - require: 
      - file: PtH.admx