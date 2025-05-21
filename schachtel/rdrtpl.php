#!/usr/bin/env php
<?php

if ($argc < 2) {
    fwrite(STDERR, "Usage: rdrtpl.php template.html VAR1=base64(VAR1) VAR2=base64(VAR2) ...\n");
    exit(1);
}

$templateFile = $argv[1];
if (!file_exists($templateFile)) {
    fwrite(STDERR, "Template file not found: $templateFile\n");
    exit(1);
}
$template = file_get_contents($templateFile);

// Parse all VAR=base64string
$vars = [];
for ($i = 2; $i < $argc; $i++) {
    if (preg_match('/^([A-Z0-9_]+)=(.*)$/', $argv[$i], $matches)) {
        $key = $matches[1];
        $decoded = base64_decode($matches[2]);
        $vars["{{$key}}"] = $decoded;
    }
}

// Replace all placeholders
echo strtr($template, $vars);
