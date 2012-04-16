#!/usr/bin/php

<?php
    $dom = new DOMDocument('1.0', 'utf-8');
    $dom->loadXML(file_get_contents('layout.xml'));
    $dom->formatOutput = true;

    function conv($src) {
        GLOBAL $dom;

        $layout = $dom->createElement('layout');    
        
        $retval = $dom->createElement('el');
        $retval->setAttribute('name', $src->getAttribute('name')); 
    
        foreach ($src->attributes as $attrName => $attr) {
            if ($attrName != 'name') {
                $layout->setAttribute($attrName, $attr->value);
            }
        }

        if ($layout->attributes->length > 0) {
            $retval->appendChild($layout);
        }
        
        $els = $src->getElementsByTagName('el');

        foreach ($els as $el) {
            $el = conv($el);
            $retval->appendChild($el);
        }

        return $retval;
    }

    $outRoot = $dom->createElement('els');
    $outRoot->appendChild(conv($dom->getElementsByTagName('layout')->item(0)));
    
    echo $dom->saveXML($outRoot);
?>
