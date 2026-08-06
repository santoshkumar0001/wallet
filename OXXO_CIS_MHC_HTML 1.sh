#!/usr/bin/env bash
# =============================================================================
# OXXO Oracle CIS / MHC HTML Assessment
# Oracle Database 19c CDB/PDB configuration inventory
#
# Usage:
#   ./OXXO_CIS_MHC_HTML.sh <ORACLE_SID> <ORACLE_HOME> [output_directory]
#
# Example:
#   ./OXXO_CIS_MHC_HTML.sh EBSCDBQA /u01/oracle/OICEBSQA/19.1.0 /home/oracle/MHC
#
# Run as the Oracle software owner.  The script connects locally as SYSDBA,
# discovers every open read-write PDB (except PDB$SEED), and performs no change
# other than ALTER SESSION SET CONTAINER in its own SQL*Plus sessions.
# =============================================================================

set -o pipefail
umask 077

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 <ORACLE_SID> <ORACLE_HOME> [output_directory]" >&2
  exit 64
fi

export ORACLE_SID="$1"
export ORACLE_HOME="$2"
export PATH="$ORACLE_HOME/bin:$PATH"

SQLPLUS="$ORACLE_HOME/bin/sqlplus"
OUTPUT_DIR="${3:-$PWD/reports}"
HOST_NAME="$(hostname -s 2>/dev/null || hostname)"
RUN_ID="$(date '+%Y%m%d_%H%M%S')"
REPORT="$OUTPUT_DIR/OXXO_CIS_MHC_${HOST_NAME}_${ORACLE_SID}_${RUN_ID}.html"

if [[ ! -x "$SQLPLUS" ]]; then
  echo "ERROR: sqlplus was not found or is not executable: $SQLPLUS" >&2
  exit 69
fi

mkdir -p "$OUTPUT_DIR" || { echo "ERROR: Cannot create $OUTPUT_DIR" >&2; exit 73; }

html_escape() {
  sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g' -e "s/'/\&#39;/g"
}

html_text() {
  printf '%s' "$1" | html_escape
}

write_html_header() {
  cat > "$REPORT" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>OXXO Oracle CIS / MHC Assessment</title>
<style>
  :root { --navy:#0b2942; --blue:#146c94; --pale:#edf5f8; --line:#cbd7df; --ink:#17212b; --muted:#5b6772; --white:#fff; }
  * { box-sizing:border-box; }
  body { margin:0; background:#f3f6f8; color:var(--ink); font:14px/1.45 Arial,Helvetica,sans-serif; }
  header { background:linear-gradient(135deg,var(--navy),#164e71); color:#fff; padding:34px max(24px,calc((100% - 1240px)/2)); }
  header h1 { margin:0 0 7px; font-size:27px; }
  header p { margin:0; color:#dcecf3; }
  main { max-width:1240px; margin:24px auto 48px; padding:0 20px; }
  .meta, .notice { background:#fff; border:1px solid var(--line); border-radius:8px; padding:18px; margin:0 0 20px; box-shadow:0 1px 2px #00111a0d; }
  .meta-grid { display:grid; grid-template-columns:repeat(auto-fit,minmax(200px,1fr)); gap:12px; }
  .meta-label { display:block; font-size:11px; color:var(--muted); font-weight:700; letter-spacing:.04em; text-transform:uppercase; }
  .meta-value { display:block; margin-top:3px; font-weight:600; overflow-wrap:anywhere; }
  .notice { border-left:5px solid var(--blue); color:#273944; }
  h2 { margin:30px 0 10px; padding:10px 14px; color:#fff; background:var(--navy); border-radius:6px; font-size:18px; }
  h3 { margin:20px 0 8px; color:var(--navy); font-size:15px; }
  .section-note { margin:0 0 10px; color:var(--muted); }
  .table-wrap { overflow-x:auto; margin:0 0 18px; border:1px solid var(--line); border-radius:6px; background:#fff; }
  table { width:100%; border-collapse:collapse; background:#fff; }
  th { background:#e1eef4; color:#16394f; font-weight:700; }
  th, td { padding:8px 10px; border:1px solid var(--line); text-align:left; vertical-align:top; white-space:normal; overflow-wrap:anywhere; }
  tr:nth-child(even) td { background:#f8fbfc; }
  details { margin:0 0 14px; border:1px solid var(--line); border-radius:6px; background:#fff; }
  summary { padding:9px 12px; cursor:pointer; color:var(--navy); font-weight:700; }
  pre { margin:0; padding:14px; overflow:auto; white-space:pre-wrap; background:#101c26; color:#e9f2f7; font:12px/1.4 Consolas,"Courier New",monospace; }
  .status-pass { color:#087a37; font-weight:700; } .status-fail { color:#b42318; font-weight:700; } .status-review { color:#8a5700; font-weight:700; }
  footer { margin-top:32px; padding:16px; border-top:1px solid var(--line); color:var(--muted); font-size:12px; }
</style>
</head>
<body>
<header>
  <h1>OXXO Oracle CIS / MHC Assessment</h1>
  <p>Oracle Database 19c configuration evidence report</p>
</header>
<main>
<section class="meta"><div class="meta-grid">
  <div><span class="meta-label">Assessment generated</span><span class="meta-value">$(html_text "$(date '+%Y-%m-%d %H:%M:%S %Z')")</span></div>
  <div><span class="meta-label">Server</span><span class="meta-value">$(html_text "$HOST_NAME")</span></div>
  <div><span class="meta-label">Oracle SID</span><span class="meta-value">$(html_text "$ORACLE_SID")</span></div>
  <div><span class="meta-label">Oracle Home</span><span class="meta-value">$(html_text "$ORACLE_HOME")</span></div>
</div></section>
<section class="notice">
  <strong>Scope and evidence.</strong> This report shows the live configuration values retrieved at assessment time. SQL text is displayed beneath every database result set. Only the <code>DEFAULT</code> password profile is assessed. Root-level CDB queries include all containers, and each open read-write PDB is also entered directly to collect its effective parameter and DEFAULT-profile values. <code>PDB\$SEED</code> is excluded.
</section>
EOF
}

write_html_footer() {
  cat >> "$REPORT" <<'EOF'
<footer>
  Generated by OXXO_CIS_MHC_HTML.sh. This report is an evidence inventory; a <strong>REVIEW</strong> result requires validation against the approved exception register and the applicable CIS benchmark.
</footer>
</main>
</body>
</html>
EOF
}

open_table() {
  printf '<div class="table-wrap"><table>\n' >> "$REPORT"
}

close_table() {
  printf '</table></div>\n' >> "$REPORT"
}

find_network_file() {
  # SQL*Net first uses TNS_ADMIN, then ORACLE_HOME/network/admin.
  local file_name="$1" candidate
  if [[ -n "${TNS_ADMIN:-}" && -r "$TNS_ADMIN/$file_name" ]]; then
    printf '%s\n' "$TNS_ADMIN/$file_name"
    return 0
  fi
  candidate="$ORACLE_HOME/network/admin/$file_name"
  [[ -r "$candidate" ]] && { printf '%s\n' "$candidate"; return 0; }
  return 1
}

find_listener_ora() {
  # The listener is often owned by Grid Infrastructure, not the database home.
  local candidate discovered
  if [[ -n "${TNS_ADMIN:-}" && -r "$TNS_ADMIN/listener.ora" ]]; then
    printf '%s\n' "$TNS_ADMIN/listener.ora"
    return 0
  fi
  candidate="$ORACLE_HOME/network/admin/listener.ora"
  [[ -r "$candidate" ]] && { printf '%s\n' "$candidate"; return 0; }

  if [[ -x "$ORACLE_HOME/bin/lsnrctl" ]]; then
    discovered="$("$ORACLE_HOME/bin/lsnrctl" status 2>/dev/null | sed -n 's/.*Listener Parameter File[[:space:]]*//p' | head -n 1)"
    [[ -n "$discovered" && -r "$discovered" ]] && { printf '%s\n' "$discovered"; return 0; }
  fi
  return 1
}

network_check() {
  local section="$1" file="$2" setting="$3" expected="$4"
  local active value command
  command="grep -Ei '^[[:space:]]*${setting}[[:space:]]*=' $(printf '%q' "$file")"
  if [[ "$file" == "<NOT DISCOVERED>" ]]; then
    value="<REVIEW: listener/sqlnet parameter file was not automatically located>"
  elif [[ -r "$file" ]]; then
    active="$(grep -Ei "^[[:space:]]*${setting}[[:space:]]*=" "$file" 2>/dev/null || true)"
    value="${active:-<NOT SET>}"
  else
    value="<FILE NOT FOUND: $file>"
  fi
  printf '<tr><td>%s</td><td>%s</td><td><code>%s</code></td><td>%s</td></tr>\n' \
    "$(html_text "$section")" "$(html_text "$expected")" "$(html_text "$value")" "$(html_text "$file")" >> "$REPORT"
}

network_search_check() {
  local section="$1" file="$2" search_text="$3" expected="$4"
  local active value
  if [[ "$file" == "<NOT DISCOVERED>" ]]; then
    value="<REVIEW: listener parameter file was not automatically located>"
  elif [[ -r "$file" ]]; then
    active="$(grep -Ei "^[[:space:]]*[^#;].*${search_text}" "$file" 2>/dev/null || true)"
    value="${active:-<NOT SET>}"
  else
    value="<FILE NOT FOUND: $file>"
  fi
  printf '<tr><td>%s</td><td>%s</td><td><code>%s</code></td><td>%s</td></tr>\n' \
    "$(html_text "$section")" "$(html_text "$expected")" "$(html_text "$value")" "$(html_text "$file")" >> "$REPORT"
}

show_shell_command() {
  local command="$1"
  cat >> "$REPORT" <<EOF
<details><summary>View executed shell command</summary><pre>$(printf '%s' "$command" | html_escape)</pre></details>
EOF
}

run_sql_fragment() {
  # $1 title, $2 container, $3 exact SQL (without the ALTER SESSION statement)
  local title="$1" container="$2" statement="$3" display_sql rc
  display_sql="alter session set container = ${container};"
  display_sql+=$'\n\n'
  display_sql+="$statement"

  printf '<h3>%s</h3>\n' "$(html_text "$title")" >> "$REPORT"
  cat >> "$REPORT" <<EOF
<details><summary>View executed SQL</summary><pre>$(printf '%s' "$display_sql" | html_escape)</pre></details>
<div class="table-wrap">
EOF

  "$SQLPLUS" -s -L '/ as sysdba' >> "$REPORT" 2>&1 <<SQL
whenever oserror exit failure rollback
whenever sqlerror exit sql.sqlcode rollback
set markup html on spool off entmap on preformat off
set feedback off verify off heading on pagesize 50000 linesize 32767 trimspool on trimout on
alter session set container = ${container};
$statement
exit success
SQL
  rc=$?
  printf '</div>\n' >> "$REPORT"
  if [[ $rc -ne 0 ]]; then
    printf '<p class="status-fail">SQL*Plus returned exit status %s for this result set. See the output above for details.</p>\n' "$rc" >> "$REPORT"
  fi
  return 0
}

discover_pdbs() {
  "$SQLPLUS" -s -L '/ as sysdba' <<'SQL'
whenever oserror exit failure rollback
whenever sqlerror exit sql.sqlcode rollback
set pagesize 0 feedback off verify off heading off echo off trimspool on
alter session set container = CDB$ROOT;
select name from v$pdbs where open_mode = 'READ WRITE' and name <> 'PDB$SEED' order by name;
exit success
SQL
}

write_html_header

if ! CDB_FLAG="$("$SQLPLUS" -s -L '/ as sysdba' <<'SQL'
whenever oserror exit failure rollback
whenever sqlerror exit sql.sqlcode rollback
set pagesize 0 feedback off verify off heading off echo off trimspool on
select cdb from v$database;
exit success
SQL
)"; then
  cat >> "$REPORT" <<'EOF'
<p class="status-fail">Unable to connect locally as SYSDBA. Confirm the script is run by the Oracle software owner and that ORACLE_SID and ORACLE_HOME are correct.</p>
EOF
  write_html_footer
  echo "ERROR: Unable to connect as SYSDBA. Partial report: $REPORT" >&2
  exit 1
fi

if [[ "$CDB_FLAG" != "YES" ]]; then
  cat >> "$REPORT" <<'EOF'
<p class="status-fail">This assessment requires an Oracle multitenant CDB. The connected database did not report CDB=YES.</p>
EOF
  write_html_footer
  echo "ERROR: Connected database is not a CDB. Partial report: $REPORT" >&2
  exit 1
fi

cat >> "$REPORT" <<'EOF'
<h2>1. Database and Container Scope</h2>
<p class="section-note">The following query establishes the database identity and confirms the root container used for CDB-wide assessment.</p>
EOF

DATABASE_ID_SQL=$(cat <<'SQL'
select d.name as database_name,
       i.instance_name,
       i.host_name,
       i.version,
       d.database_role,
       d.open_mode,
       sys_context('USERENV','CON_NAME') as current_container
from v$database d cross join v$instance i;
SQL
)
run_sql_fragment "Database identity (root container)" "CDB\$ROOT" "$DATABASE_ID_SQL"

PDB_LIST_SQL=$(cat <<'SQL'
select con_id, name as pdb_name, open_mode, restricted, open_time
from v$pdbs
where name <> 'PDB$SEED'
order by con_id;
SQL
)
run_sql_fragment "Discovered pluggable databases" "CDB\$ROOT" "$PDB_LIST_SQL"

cat >> "$REPORT" <<'EOF'
<h2>2. Oracle Net Configuration Evidence</h2>
<p class="section-note">Only active, uncommented settings are shown. A <code>&lt;NOT SET&gt;</code> value means no active matching parameter was found in the specified file.</p>
EOF
open_table
cat >> "$REPORT" <<'EOF'
<tr><th>CIS section</th><th>Expected value</th><th>Actual active setting</th><th>Source file</th></tr>
EOF

LISTENER_ORA="$(find_listener_ora || true)"
SQLNET_ORA="$(find_network_file sqlnet.ora || true)"
LISTENER_ORA="${LISTENER_ORA:-<NOT DISCOVERED>}"
SQLNET_ORA="${SQLNET_ORA:-<NOT DISCOVERED>}"
network_search_check "2.1.1" "$LISTENER_ORA" "EXTPROC" "extproc not enabled"
network_check "2.1.2" "$LISTENER_ORA" "ACCEPT_MD5_CERTS" "Not TRUE"
network_check "2.1.3" "$LISTENER_ORA" "ACCEPT_SHA1_CERTS" "Not TRUE"
network_check "2.1.4" "$LISTENER_ORA" "ALLOWED_WEAK_CERT_ALGORITHMS" "Not set or NONE"
network_check "2.2.1" "$SQLNET_ORA" "ACCEPT_MD5_CERTS" "Not TRUE"
network_check "2.2.2" "$SQLNET_ORA" "ACCEPT_SHA1_CERTS" "Not TRUE"
network_check "2.2.3" "$SQLNET_ORA" "ALLOWED_WEAK_CERT_ALGORITHMS" "Not set or NONE"
network_check "2.2.4" "$SQLNET_ORA" "SQLNET\\.ALLOWED_LOGON_VERSION_CLIENT" "12a"
network_check "2.2.5" "$SQLNET_ORA" "SQLNET\\.ALLOWED_LOGON_VERSION_SERVER" "12a"
network_check "2.2.6" "$SQLNET_ORA" "SQLNET\\.ENCRYPTION_CLIENT" "REQUIRED"
network_check "2.2.7" "$SQLNET_ORA" "SQLNET\\.ENCRYPTION_SERVER" "REQUIRED"
network_check "2.2.8" "$SQLNET_ORA" "SQLNET\\.ENCRYPTION_TYPES_CLIENT" "(AES256)"
network_check "2.2.10" "$SQLNET_ORA" "SQLNET\\.CRYPTO_CHECKSUM_CLIENT" "REQUIRED"
network_check "2.2.11" "$SQLNET_ORA" "SQLNET\\.CRYPTO_CHECKSUM_SERVER" "REQUIRED"
close_table
show_shell_command "grep -Ei '^[[:space:]]*<PARAMETER>[[:space:]]*=' <listener.ora|sqlnet.ora>"

cat >> "$REPORT" <<'EOF'
<h2>3. CDB-Wide Parameter and Default Profile Evidence</h2>
<p class="section-note">This root query returns the effective values recorded for every container and RAC instance. The detailed PDB checks in the next section also enter every discovered PDB directly.</p>
EOF

CDB_PARAMETER_SQL=$(cat <<'SQL'
with controls (section, parameter, expected_value) as (
  select '2.3.1','BACKGROUND_CORE_DUMP','NOT FULL' from dual union all
  select '2.3.2','SHADOW_CORE_DUMP','NOT FULL' from dual union all
  select '2.3.3','ALLOW_GROUP_ACCESS_TO_SGA','FALSE' from dual union all
  select '2.3.5','OS_ROLES','FALSE' from dual union all
  select '2.3.6','REMOTE_OS_ROLES','FALSE' from dual union all
  select '2.3.7','SEC_MAX_FAILED_LOGIN_ATTEMPTS','<= 3' from dual union all
  select '2.3.8','SEC_PROTOCOL_ERROR_FURTHER_ACTION','(DROP,3)' from dual union all
  select '2.3.9','SEC_PROTOCOL_ERROR_TRACE_ACTION','LOG' from dual union all
  select '2.3.10','SEC_RETURN_SERVER_RELEASE_BANNER','FALSE' from dual union all
  select '2.3.11','REMOTE_LOGIN_PASSWORDFILE','NONE (or EXCLUSIVE with Data Guard)' from dual union all
  select '2.3.12','REMOTE_LISTENER','EMPTY / NULL' from dual union all
  select '2.3.13','RESOURCE_LIMIT','TRUE' from dual union all
  select '2.3.14','REMOTE_OS_AUTHENT','FALSE' from dual union all
  select '2.3.15','SEC_CASE_SENSITIVE_LOGON','TRUE (where parameter exists)' from dual
), params as (
  select inst_id, con_id, upper(name) parameter, nvl(value,'<NULL>') actual_value
  from gv$system_parameter
  where upper(name) in (select parameter from controls)
)
select c.section,
       p.inst_id,
       decode(p.con_id,0,'ENTIRE-'||sys_context('USERENV','DB_NAME'),1,'ROOTONLY-'||sys_context('USERENV','DB_NAME'),con_id_to_con_name(p.con_id)) as container_name,
       c.parameter,
       nvl(p.actual_value,'<PARAMETER NOT FOUND>') as actual_value,
       c.expected_value,
       case
         when p.parameter is null then 'REVIEW'
         when c.parameter in ('BACKGROUND_CORE_DUMP','SHADOW_CORE_DUMP') and upper(p.actual_value) <> 'FULL' then 'PASS'
         when c.parameter in ('ALLOW_GROUP_ACCESS_TO_SGA','OS_ROLES','REMOTE_OS_ROLES','SEC_RETURN_SERVER_RELEASE_BANNER','REMOTE_OS_AUTHENT') and upper(p.actual_value) = 'FALSE' then 'PASS'
         when c.parameter='SEC_MAX_FAILED_LOGIN_ATTEMPTS' and regexp_like(p.actual_value,'^[0-9]+$') and to_number(p.actual_value) <= 3 then 'PASS'
         when c.parameter='SEC_PROTOCOL_ERROR_FURTHER_ACTION' and replace(upper(p.actual_value),' ','') in ('(DROP,3)','DROP,3') then 'PASS'
         when c.parameter='SEC_PROTOCOL_ERROR_TRACE_ACTION' and upper(p.actual_value)='LOG' then 'PASS'
         when c.parameter='REMOTE_LOGIN_PASSWORDFILE' and upper(p.actual_value) in ('NONE','EXCLUSIVE') then 'REVIEW'
         when c.parameter='REMOTE_LISTENER' and p.actual_value='<NULL>' then 'PASS'
         when c.parameter='RESOURCE_LIMIT' and upper(p.actual_value)='TRUE' then 'PASS'
         when c.parameter='SEC_CASE_SENSITIVE_LOGON' and upper(p.actual_value)='TRUE' then 'PASS'
         else 'FAIL'
       end as compliance
from controls c left join params p on p.parameter=c.parameter
order by c.section, p.inst_id nulls last, p.con_id nulls last;
SQL
)
run_sql_fragment "CIS 2.3 initialization parameters (all containers)" "CDB\$ROOT" "$CDB_PARAMETER_SQL"

DEFAULT_PROFILE_SQL=$(cat <<'SQL'
select case resource_name
         when 'FAILED_LOGIN_ATTEMPTS' then '3.1'
         when 'PASSWORD_LOCK_TIME' then '3.2'
         when 'PASSWORD_LIFE_TIME' then '3.3'
         when 'PASSWORD_GRACE_TIME' then '3.3'
         when 'PASSWORD_REUSE_MAX' then '3.4'
         when 'PASSWORD_VERIFY_FUNCTION' then '3.5'
         when 'PASSWORD_ROLLOVER_TIME' then '3.7'
         when 'INACTIVE_ACCOUNT_TIME' then '3.8'
       end as section,
       decode(con_id,0,'ENTIRE-'||sys_context('USERENV','DB_NAME'),1,'ROOTONLY-'||sys_context('USERENV','DB_NAME'),con_id_to_con_name(con_id)) as container_name,
       profile,
       resource_name as parameter,
       limit as actual_value,
       case resource_name
         when 'FAILED_LOGIN_ATTEMPTS' then '<= 5'
         when 'PASSWORD_LOCK_TIME' then '>= 1'
         when 'PASSWORD_LIFE_TIME' then 'With PASSWORD_GRACE_TIME <= 365'
         when 'PASSWORD_GRACE_TIME' then 'With PASSWORD_LIFE_TIME <= 365'
         when 'PASSWORD_REUSE_MAX' then 'UNLIMITED'
         when 'PASSWORD_VERIFY_FUNCTION' then 'NOT NULL'
         when 'PASSWORD_ROLLOVER_TIME' then '0'
         when 'INACTIVE_ACCOUNT_TIME' then '<= 120'
       end as expected_value
from cdb_profiles
where profile='DEFAULT'
  and resource_name in ('FAILED_LOGIN_ATTEMPTS','PASSWORD_LOCK_TIME','PASSWORD_LIFE_TIME','PASSWORD_GRACE_TIME',
                        'PASSWORD_REUSE_MAX','PASSWORD_VERIFY_FUNCTION','PASSWORD_ROLLOVER_TIME','INACTIVE_ACCOUNT_TIME')
order by section, con_id, resource_name;
SQL
)
run_sql_fragment "CIS Section 3 - DEFAULT profile only (all containers)" "CDB\$ROOT" "$DEFAULT_PROFILE_SQL"

PROFILE_TOTAL_SQL=$(cat <<'SQL'
with profile_values as (
  select con_id, profile,
         max(case when resource_name='PASSWORD_LIFE_TIME' then limit end) as password_life_time,
         max(case when resource_name='PASSWORD_GRACE_TIME' then limit end) as password_grace_time
  from cdb_profiles
  where profile='DEFAULT' and resource_name in ('PASSWORD_LIFE_TIME','PASSWORD_GRACE_TIME')
  group by con_id, profile
)
select '3.3' as section,
       decode(con_id,0,'ENTIRE-'||sys_context('USERENV','DB_NAME'),1,'ROOTONLY-'||sys_context('USERENV','DB_NAME'),con_id_to_con_name(con_id)) as container_name,
       profile, password_life_time, password_grace_time,
       'Password life time plus grace time must be <= 365; inspect literal values shown' as expected_value
from profile_values
order by con_id;
SQL
)
run_sql_fragment "CIS 3.3 - DEFAULT profile life and grace values" "CDB\$ROOT" "$PROFILE_TOTAL_SQL"

if ! PDBS="$(discover_pdbs)"; then
  PDBS=""
  cat >> "$REPORT" <<'EOF'
<p class="status-fail">PDB discovery failed. CDB-wide results above remain available; confirm access to V$PDBS.</p>
EOF
fi

cat >> "$REPORT" <<'EOF'
<h2>4. Direct Pluggable Database Evidence</h2>
<p class="section-note">The script now switches into each discovered PDB and obtains its effective values directly. This validates the container-specific settings rather than relying only on root aggregation.</p>
EOF

PDB_PARAMETER_SQL=$(cat <<'SQL'
with controls (section, parameter, expected_value) as (
  select '2.3.1','BACKGROUND_CORE_DUMP','NOT FULL' from dual union all
  select '2.3.2','SHADOW_CORE_DUMP','NOT FULL' from dual union all
  select '2.3.3','ALLOW_GROUP_ACCESS_TO_SGA','FALSE' from dual union all
  select '2.3.5','OS_ROLES','FALSE' from dual union all
  select '2.3.6','REMOTE_OS_ROLES','FALSE' from dual union all
  select '2.3.7','SEC_MAX_FAILED_LOGIN_ATTEMPTS','<= 3' from dual union all
  select '2.3.8','SEC_PROTOCOL_ERROR_FURTHER_ACTION','(DROP,3)' from dual union all
  select '2.3.9','SEC_PROTOCOL_ERROR_TRACE_ACTION','LOG' from dual union all
  select '2.3.10','SEC_RETURN_SERVER_RELEASE_BANNER','FALSE' from dual union all
  select '2.3.11','REMOTE_LOGIN_PASSWORDFILE','NONE (or EXCLUSIVE with Data Guard)' from dual union all
  select '2.3.12','REMOTE_LISTENER','EMPTY / NULL' from dual union all
  select '2.3.13','RESOURCE_LIMIT','TRUE' from dual union all
  select '2.3.14','REMOTE_OS_AUTHENT','FALSE' from dual union all
  select '2.3.15','SEC_CASE_SENSITIVE_LOGON','TRUE (where parameter exists)' from dual
)
select c.section,
       sys_context('USERENV','CON_NAME') as container_name,
       c.parameter,
       nvl(p.value,'<PARAMETER NOT FOUND>') as actual_value,
       c.expected_value
from controls c left join v$system_parameter p on upper(p.name)=c.parameter
order by c.section;
SQL
)

PDB_PROFILE_SQL=$(cat <<'SQL'
select case resource_name
         when 'FAILED_LOGIN_ATTEMPTS' then '3.1'
         when 'PASSWORD_LOCK_TIME' then '3.2'
         when 'PASSWORD_LIFE_TIME' then '3.3'
         when 'PASSWORD_GRACE_TIME' then '3.3'
         when 'PASSWORD_REUSE_MAX' then '3.4'
         when 'PASSWORD_VERIFY_FUNCTION' then '3.5'
         when 'PASSWORD_ROLLOVER_TIME' then '3.7'
         when 'INACTIVE_ACCOUNT_TIME' then '3.8'
       end as section,
       sys_context('USERENV','CON_NAME') as container_name,
       resource_name as parameter,
       limit as actual_value,
       'DEFAULT profile only' as scope
from dba_profiles
where profile='DEFAULT'
  and resource_name in ('FAILED_LOGIN_ATTEMPTS','PASSWORD_LOCK_TIME','PASSWORD_LIFE_TIME','PASSWORD_GRACE_TIME',
                        'PASSWORD_REUSE_MAX','PASSWORD_VERIFY_FUNCTION','PASSWORD_ROLLOVER_TIME','INACTIVE_ACCOUNT_TIME')
order by section, resource_name;
SQL
)

PDB_DBLINK_SQL=$(cat <<'SQL'
select '4.7/4.8' as section,
       sys_context('USERENV','CON_NAME') as container_name,
       owner||'.'||db_link as database_link,
       host||'; USERNAME='||username as actual_value,
       case when owner='PUBLIC' then 'No PUBLIC database links' else 'Review database-link encryption separately' end as expected_value
from dba_db_links
union all
select '4.8' as section,
       sys_context('USERENV','CON_NAME') as container_name,
       name as database_link,
       'PASSWORDX_PREFIX='||nvl(substr(passwordx,1,2),'<NULL>') as actual_value,
       'PasswordX prefix 06 (latest database-link encryption)' as expected_value
from sys.link$
order by 1, 2, 3;
SQL
)

PDB_USER_SECURITY_SQL=$(cat <<'SQL'
select '4.1' as section,
       sys_context('USERENV','CON_NAME') as container_name,
       u.username,
       u.account_status as actual_value,
       'No default passwords' as expected_value
from dba_users_with_defpwd d
join dba_users u on u.username=d.username
union all
select '4.2/4.4' as section,
       sys_context('USERENV','CON_NAME') as container_name,
       username,
       oracle_maintained||'; PASSWORD_VERSIONS='||nvl(password_versions,'<NULL>') as actual_value,
       'Review custom Oracle-maintained users; password versions should be 12C only' as expected_value
from dba_users
order by 1, 2, 3;
SQL
)

PDB_AUDIT_SQL=$(cat <<'SQL'
select case
         when p.audit_option_type in ('SYSTEM PRIVILEGE','STANDARD ACTION') then '5.1.1/5.1.2'
         when p.audit_option_type='OBJECT ACTION' then '5.1.3/5.1.4'
         else '5.1.5'
       end as section,
       sys_context('USERENV','CON_NAME') as container_name,
       p.policy_name||': '||p.audit_option_type||' '||p.audit_option as audit_configuration,
       'SUCCESS='||nvl(e.success,'NO')||'; FAILURE='||nvl(e.failure,'NO')||'; ENTITY='||nvl(e.entity_name,'ALL USERS') as actual_value,
       'Enabled audit policy; review CIS required action list' as expected_value
from audit_unified_policies p
left join audit_unified_enabled_policies e on e.policy_name=p.policy_name
order by 1, 3;
SQL
)

PDB_SYSTEM_PRIV_SQL=$(cat <<'SQL'
with section_map(section, privilege_pattern, admin_only) as (
  select '6.1.1','.*ANY.*','N' from dual union all
  select '6.1.2','.*','Y' from dual union all
  select '6.1.3','IMPORT FULL DATABASE|EXPORT FULL DATABASE','N' from dual union all
  select '6.1.4','CREATE EXTERNAL JOB','N' from dual union all
  select '6.1.5','BECOME USER','N' from dual union all
  select '6.1.6','TEXT DATASTORE ACCESS','N' from dual union all
  select '6.1.7','CREATE PUBLIC DATABASE LINK|ALTER PUBLIC DATABASE LINK|DROP PUBLIC DATABASE LINK','N' from dual union all
  select '6.1.8','LOGMINING','N' from dual union all
  select '6.1.9','ALTER SYSTEM','N' from dual union all
  select '6.1.10','CREATE LIBRARY','N' from dual union all
  select '6.1.11','.*','N' from dual
), non_oracle_grantees as (
  select username as grantee from dba_users where oracle_maintained='N'
  union
  select role as grantee from dba_roles where oracle_maintained='N'
)
select m.section,
       sys_context('USERENV','CON_NAME') as container_name,
       s.grantee,
       s.privilege as granted_privilege,
       'ADMIN_OPTION='||s.admin_option||'; COMMON='||s.common||'; INHERITED='||s.inherited as actual_value,
       'No unauthorized grants; validate approved exceptions' as expected_value,
       'REVIEW' as compliance
from section_map m
join dba_sys_privs s on regexp_like(s.privilege,m.privilege_pattern)
join non_oracle_grantees g on g.grantee=s.grantee
where m.admin_only='N' or s.admin_option='YES'
order by m.section, s.grantee, s.privilege;
SQL
)

PDB_ROLE_PRIV_SQL=$(cat <<'SQL'
with section_map(section, role_name) as (
  select '6.2.1','DBA' from dual union all select '6.2.2','EXP_FULL_DATABASE' from dual union all
  select '6.2.3','IMP_FULL_DATABASE' from dual union all select '6.2.4','DATAPUMP_EXP_FULL_DATABASE' from dual union all
  select '6.2.5','DATAPUMP_IMP_FULL_DATABASE' from dual union all select '6.2.6','DV_ADMIN' from dual union all
  select '6.2.7','DV_AUDIT_CLEANUP' from dual union all select '6.2.8','OLAP_DBA' from dual union all
  select '6.2.9','LBAC_DBA' from dual union all select '6.2.10','JAVA_ADMIN' from dual union all
  select '6.2.11','JAVAUSERPRIV' from dual union all select '6.2.12','LOGSTDBY_ADMINISTRATOR' from dual union all
  select '6.2.13','MAINTPLAN_APP' from dual union all select '6.2.14','JAVADEBUGPRIV' from dual union all
  select '6.2.15','DV_PATCH_ADMIN' from dual union all select '6.2.16','DV_POLICY_OWNER' from dual union all
  select '6.2.17','AUDIT_ADMIN' from dual union all select '6.2.18','AUDIT_VIEWER' from dual union all
  select '6.2.19','PDB_DBA' from dual union all select '6.2.20','SELECT_CATALOG_ROLE' from dual union all
  select '6.2.21','EXECUTE_CATALOG_ROLE' from dual
), non_oracle_grantees as (
  select username as grantee from dba_users where oracle_maintained='N'
  union
  select role as grantee from dba_roles where oracle_maintained='N'
)
select m.section,
       sys_context('USERENV','CON_NAME') as container_name,
       r.grantee,
       r.granted_role,
       'ADMIN_OPTION='||r.admin_option||'; COMMON='||r.common||'; INHERITED='||r.inherited as actual_value,
       'No unauthorized grants; validate approved exceptions' as expected_value,
       'REVIEW' as compliance
from section_map m
join dba_role_privs r on r.granted_role=m.role_name
join non_oracle_grantees g on g.grantee=r.grantee
order by m.section, r.grantee;
SQL
)

PDB_SENSITIVE_TABLE_SQL=$(cat <<'SQL'
select '6.3.1' as section,
       sys_context('USERENV','CON_NAME') as container_name,
       grantee,
       owner||'.'||table_name||' : '||privilege as granted_privilege,
       'GRANTABLE='||grantable as actual_value,
       'No unauthorized grants on sensitive SYS tables' as expected_value,
       'REVIEW' as compliance
from dba_tab_privs
where owner='SYS'
  and table_name in ('CDB_LOCAL_ADMINAUTH$','DEFAULT_PWD$','ENC$','HISTGRM$','HIST_HEAD$',
                     'LINK$','PDB_SYNC$','SCHEDULER$_CREDENTIAL','USER$','USER_HISTORY$','XS$VERIFIERS')
order by grantee, table_name, privilege;
SQL
)

PDB_COUNT=0
while IFS= read -r PDB; do
  PDB="${PDB//$'\r'/}"
  [[ -z "$PDB" ]] && continue
  if [[ ! "$PDB" =~ ^[A-Za-z0-9_\$#]+$ ]]; then
    printf '<p class="status-fail">Skipped an invalid PDB identifier returned by discovery: %s</p>\n' "$(html_text "$PDB")" >> "$REPORT"
    continue
  fi
  PDB_COUNT=$((PDB_COUNT + 1))
  printf '<h3>Pluggable database: %s</h3>\n' "$(html_text "$PDB")" >> "$REPORT"
  run_sql_fragment "Effective CIS 2.3 parameter values" "$PDB" "$PDB_PARAMETER_SQL"
  run_sql_fragment "DEFAULT profile values" "$PDB" "$PDB_PROFILE_SQL"
  run_sql_fragment "CIS 4.1, 4.2, and 4.4 - user inventory" "$PDB" "$PDB_USER_SECURITY_SQL"
  run_sql_fragment "Database-link inventory" "$PDB" "$PDB_DBLINK_SQL"
  run_sql_fragment "CIS Section 5 - unified audit policy inventory" "$PDB" "$PDB_AUDIT_SQL"
  run_sql_fragment "CIS 6.1 - system privilege inventory" "$PDB" "$PDB_SYSTEM_PRIV_SQL"
  run_sql_fragment "CIS 6.2 - privileged role inventory" "$PDB" "$PDB_ROLE_PRIV_SQL"
  run_sql_fragment "CIS 6.3.1 - sensitive SYS-table privileges" "$PDB" "$PDB_SENSITIVE_TABLE_SQL"
done <<< "$PDBS"

if [[ $PDB_COUNT -eq 0 ]]; then
  cat >> "$REPORT" <<'EOF'
<p class="status-review">No open read-write PDBs were found. PDB$SEED is intentionally not assessed.</p>
EOF
fi

cat >> "$REPORT" <<'EOF'
<h2>5. Users, Password Files, and Audit Configuration</h2>
<p class="section-note">These CDB-root inventory queries return data from all containers through CDB views. Values are displayed as evidence, not suppressed when compliant.</p>
EOF

USER_SECURITY_SQL=$(cat <<'SQL'
select '4.1' as section,
       decode(u.con_id,0,'ENTIRE-'||sys_context('USERENV','DB_NAME'),1,'ROOTONLY-'||sys_context('USERENV','DB_NAME'),con_id_to_con_name(u.con_id)) as container_name,
       u.username,
       u.account_status as actual_value,
       'No default passwords' as expected_value
from cdb_users_with_defpwd d
join cdb_users u on u.con_id=d.con_id and u.username=d.username
union all
select '4.2/4.4' as section,
       decode(con_id,0,'ENTIRE-'||sys_context('USERENV','DB_NAME'),1,'ROOTONLY-'||sys_context('USERENV','DB_NAME'),con_id_to_con_name(con_id)) as container_name,
       username,
       oracle_maintained||'; PASSWORD_VERSIONS='||nvl(password_versions,'<NULL>') as actual_value,
       'Review custom Oracle-maintained users; password versions should be 12C only' as expected_value
from cdb_users
order by section, container_name, username;
SQL
)
run_sql_fragment "CIS 4.1, 4.2, and 4.4 - user inventory" "CDB\$ROOT" "$USER_SECURITY_SQL"
run_sql_fragment "CIS 4.7 and 4.8 - root database-link inventory" "CDB\$ROOT" "$PDB_DBLINK_SQL"

PASSWORD_FILE_SQL=$(cat <<'SQL'
select '4.5' as section,
       to_char(inst_id) as instance_id,
       'PASSWORD_FILE_FORMAT' as item,
       format as actual_value,
       '12.2' as expected_value,
       case when format='12.2' then 'PASS' else 'FAIL' end as compliance
from gv$passwordfile_info
union all
select '4.6' as section,
       to_char(inst_id) as instance_id,
       username as item,
       'SYSDBA='||sysdba||'; SYSOPER='||sysoper||'; SYSBACKUP='||sysbackup||'; SYSDG='||sysdg||'; SYSKM='||syskm as actual_value,
       'Same user set and privileges on every RAC instance' as expected_value,
       'REVIEW' as compliance
from gv$pwfile_users
order by section, instance_id, item;
SQL
)
run_sql_fragment "CIS 4.5 and 4.6 - password-file inventory" "CDB\$ROOT" "$PASSWORD_FILE_SQL"

AUDIT_SQL=$(cat <<'SQL'
select case
         when p.audit_option_type in ('SYSTEM PRIVILEGE','STANDARD ACTION') then '5.1.1/5.1.2'
         when p.audit_option_type='OBJECT ACTION' then '5.1.3/5.1.4'
         else '5.1.5'
       end as section,
       decode(p.con_id,0,'ENTIRE-'||sys_context('USERENV','DB_NAME'),1,'ROOTONLY-'||sys_context('USERENV','DB_NAME'),con_id_to_con_name(p.con_id)) as container_name,
       p.policy_name||': '||p.audit_option_type||' '||p.audit_option as audit_configuration,
       'SUCCESS='||nvl(e.success,'NO')||'; FAILURE='||nvl(e.failure,'NO')||'; ENTITY='||nvl(e.entity_name,'ALL USERS') as actual_value,
       'Enabled audit policy; review CIS required action list' as expected_value
from cdb_audit_unified_policies p
left join containers(audit_unified_enabled_policies) e
  on e.con_id=p.con_id and e.policy_name=p.policy_name
order by section, p.con_id, p.policy_name, p.audit_option;
SQL
)
run_sql_fragment "CIS Section 5 - unified audit policy inventory" "CDB\$ROOT" "$AUDIT_SQL"

cat >> "$REPORT" <<'EOF'
<h2>6. Privileged Access Evidence</h2>
<p class="section-note">All identified grants are presented for validation against the approved access-exception register. This is deliberately an inventory, not an exception-only report.</p>
EOF

SYSTEM_PRIV_SQL=$(cat <<'SQL'
with section_map(section, privilege_pattern, admin_only) as (
  select '6.1.1','.*ANY.*','N' from dual union all
  select '6.1.2','.*','Y' from dual union all
  select '6.1.3','IMPORT FULL DATABASE|EXPORT FULL DATABASE','N' from dual union all
  select '6.1.4','CREATE EXTERNAL JOB','N' from dual union all
  select '6.1.5','BECOME USER','N' from dual union all
  select '6.1.6','TEXT DATASTORE ACCESS','N' from dual union all
  select '6.1.7','CREATE PUBLIC DATABASE LINK|ALTER PUBLIC DATABASE LINK|DROP PUBLIC DATABASE LINK','N' from dual union all
  select '6.1.8','LOGMINING','N' from dual union all
  select '6.1.9','ALTER SYSTEM','N' from dual union all
  select '6.1.10','CREATE LIBRARY','N' from dual union all
  select '6.1.11','.*','N' from dual
), non_oracle_grantees as (
  select con_id, username as grantee from cdb_users where oracle_maintained='N'
  union
  select con_id, role as grantee from cdb_roles where oracle_maintained='N'
)
select m.section,
       decode(s.con_id,0,'ENTIRE-'||sys_context('USERENV','DB_NAME'),1,'ROOTONLY-'||sys_context('USERENV','DB_NAME'),con_id_to_con_name(s.con_id)) as container_name,
       s.grantee,
       s.privilege as granted_privilege,
       'ADMIN_OPTION='||s.admin_option||'; COMMON='||s.common||'; INHERITED='||s.inherited as actual_value,
       'No unauthorized grants; validate approved exceptions' as expected_value,
       'REVIEW' as compliance
from section_map m
join cdb_sys_privs s on regexp_like(s.privilege,m.privilege_pattern)
join non_oracle_grantees g on g.con_id=s.con_id and g.grantee=s.grantee
where m.admin_only='N' or s.admin_option='YES'
order by m.section, s.con_id, s.grantee, s.privilege;
SQL
)
run_sql_fragment "CIS 6.1 - system privilege inventory" "CDB\$ROOT" "$SYSTEM_PRIV_SQL"

ROLE_PRIV_SQL=$(cat <<'SQL'
with section_map(section, role_name) as (
  select '6.2.1','DBA' from dual union all select '6.2.2','EXP_FULL_DATABASE' from dual union all
  select '6.2.3','IMP_FULL_DATABASE' from dual union all select '6.2.4','DATAPUMP_EXP_FULL_DATABASE' from dual union all
  select '6.2.5','DATAPUMP_IMP_FULL_DATABASE' from dual union all select '6.2.6','DV_ADMIN' from dual union all
  select '6.2.7','DV_AUDIT_CLEANUP' from dual union all select '6.2.8','OLAP_DBA' from dual union all
  select '6.2.9','LBAC_DBA' from dual union all select '6.2.10','JAVA_ADMIN' from dual union all
  select '6.2.11','JAVAUSERPRIV' from dual union all select '6.2.12','LOGSTDBY_ADMINISTRATOR' from dual union all
  select '6.2.13','MAINTPLAN_APP' from dual union all select '6.2.14','JAVADEBUGPRIV' from dual union all
  select '6.2.15','DV_PATCH_ADMIN' from dual union all select '6.2.16','DV_POLICY_OWNER' from dual union all
  select '6.2.17','AUDIT_ADMIN' from dual union all select '6.2.18','AUDIT_VIEWER' from dual union all
  select '6.2.19','PDB_DBA' from dual union all select '6.2.20','SELECT_CATALOG_ROLE' from dual union all
  select '6.2.21','EXECUTE_CATALOG_ROLE' from dual
), non_oracle_grantees as (
  select con_id, username as grantee from cdb_users where oracle_maintained='N'
  union
  select con_id, role as grantee from cdb_roles where oracle_maintained='N'
)
select m.section,
       decode(r.con_id,0,'ENTIRE-'||sys_context('USERENV','DB_NAME'),1,'ROOTONLY-'||sys_context('USERENV','DB_NAME'),con_id_to_con_name(r.con_id)) as container_name,
       r.grantee,
       r.granted_role,
       'ADMIN_OPTION='||r.admin_option||'; COMMON='||r.common||'; INHERITED='||r.inherited as actual_value,
       'No unauthorized grants; validate approved exceptions' as expected_value,
       'REVIEW' as compliance
from section_map m
join cdb_role_privs r on r.granted_role=m.role_name
join non_oracle_grantees g on g.con_id=r.con_id and g.grantee=r.grantee
order by m.section, r.con_id, r.grantee;
SQL
)
run_sql_fragment "CIS 6.2 - privileged role inventory" "CDB\$ROOT" "$ROLE_PRIV_SQL"

SENSITIVE_TABLE_SQL=$(cat <<'SQL'
select '6.3.1' as section,
       decode(con_id,0,'ENTIRE-'||sys_context('USERENV','DB_NAME'),1,'ROOTONLY-'||sys_context('USERENV','DB_NAME'),con_id_to_con_name(con_id)) as container_name,
       grantee,
       owner||'.'||table_name||' : '||privilege as granted_privilege,
       'GRANTABLE='||grantable||'; COMMON='||common||'; INHERITED='||inherited as actual_value,
       'No unauthorized grants on sensitive SYS tables' as expected_value,
       'REVIEW' as compliance
from cdb_tab_privs
where owner='SYS'
  and table_name in ('CDB_LOCAL_ADMINAUTH$','DEFAULT_PWD$','ENC$','HISTGRM$','HIST_HEAD$',
                     'LINK$','PDB_SYNC$','SCHEDULER$_CREDENTIAL','USER$','USER_HISTORY$','XS$VERIFIERS')
order by con_id, grantee, table_name, privilege;
SQL
)
run_sql_fragment "CIS 6.3.1 - sensitive SYS-table privileges" "CDB\$ROOT" "$SENSITIVE_TABLE_SQL"

write_html_footer
chmod 600 "$REPORT"
printf 'HTML assessment created: %s\n' "$REPORT"
