#!/usr/bin/env php

<?php
// tiny templater
// Usage: rdrtpl.php template.html VAR1=base64(VAR1) VAR2=base64(VAR2) ...

// enough paramters
if ($argc < 2) exit(1);

// get template file
$templateFile = $argv[1];
if (!file_exists(filename: $templateFile)) exit(1);

// get templete contents
$template = file_get_contents(filename: $templateFile);

// Parse all VAR=base64string
$vars = [];
for ($i = 2; $i < $argc; $i++) {
    if (preg_match(pattern: '/^([A-Z0-9_]+)=(.*)$/', subject: $argv[$i], matches: $matches)) {
        $key = $matches[1];
        $decoded = base64_decode(string: $matches[2]);
        $vars['{{'.$key.'}}'] = $decoded;
    }
}

// Replace all placeholders
echo strtr($template, $vars);
