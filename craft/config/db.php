<?php

/**
 * Database Configuration
 *
 * All of your system's database configuration settings go in here.
 * You can see a list of the default settings in craft/app/etc/config/defaults/db.php
 */

return array(
    '*' => array(
        'tablePrefix' => 'craft',
        'server' => '127.0.0.1',
        'user' => getenv("MYSQL_USER"),
        'password' => getenv("MYSQL_PASS"),
        'database' => getenv("MYSQL_DB"),
    ),
);
