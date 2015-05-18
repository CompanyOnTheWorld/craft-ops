<?php

// Environment to be used in craft/config/general.php
define('CRAFT_ENVIRONMENT', getenv('CRAFT_ENVIRONMENT'));

// Path to your craft/ folder
define('CRAFT_PATH', getenv('CRAFT_PATH'));

// Do not edit below this line
$path = rtrim(CRAFT_PATH, '/').'/app/index.php';

if (!is_file($path))
{
	if (function_exists('http_response_code'))
	{
		http_response_code(503);
	}

	exit('Could not find your craft/ folder. Please ensure that <strong><code>$craftPath</code></strong> is set correctly in '.__FILE__);
}

require_once $path;
