<?php

$config->custom->appearance['friendly_attrs'] = array(
    'facsimileTelephoneNumber' => 'Fax',
    'uid'                      => 'User Name',
    'mail'                     => 'Email',
    'telephoneNumber'          => 'Phone Number',
    'mobile'                   => 'Mobile Number',
    'pager'                    => 'Pager Number',
    'cn'                       => 'Full Name',
    'gidNumber'                => 'Group ID',
    'uidNumber'                => 'User ID',
    'homeDirectory'            => 'Home Directory',
    'loginShell'               => 'Login Shell',
    'gecos'                    => 'GECOS',
    'shadowLastChange'         => 'Last Password Change',
    'shadowMax'                => 'Maximum Password Age',
    'shadowWarning'            => 'Password Warning',
    'shadowInactive'           => 'Password Inactive',
    'shadowExpire'             => 'Password Expire',
    'shadowFlag'               => 'Password Flag',
    'memberUid'                => 'Group Members',
    'memberOf'                 => 'Group Membership'
);

$servers = new Datastore();

$servers->newServer('ldap_pla');

$servers->setValue('server','name','OpenLDAP Server');
$servers->setValue('server','host', getenv('PHPLDAPADMIN_LDAP_HOSTS') ?: 'openldap');
$servers->setValue('server','port',389);
$servers->setValue('server','base',array(getenv('LDAP_BASE_DN') ?: 'dc=example,dc=com'));
$servers->setValue('login','auth_type','session');
$servers->setValue('login','attr','dn');
$servers->setValue('login','anon_bind',false);
$servers->setValue('appearance','password_hash','ssha');
$servers->setValue('appearance','show_create',true);
$servers->setValue('appearance','show_top_create',$config->getValue('appearance','show_create'));
$servers->setValue('appearance','charset','utf-8');
$servers->setValue('appearance','timezone',date_default_timezone_get() ?: 'UTC');

$config->custom->appearance['hide_template_warning'] = true;
$config->custom->appearance['custom_templates_only'] = false;
$config->custom->appearance['disable_default_template'] = false;

$config->custom->appearance['tree_width'] = 300;
$config->custom->appearance['tree_height'] = 400;
$config->custom->appearance['date'] = '%Y-%m-%d %H:%M:%S';
$config->custom->appearance['time'] = '%H:%M:%S';

$config->custom->session['blowfish'] = null;
$config->custom->session['memory_limit'] = '64M';

$config->custom->search['size_limit'] = 1000;
$config->custom->search['children_limit'] = 1000;

$config->setDebug(false);
?>
