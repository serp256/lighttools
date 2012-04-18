#!/usr/bin/php

<?php
    $dom = new DOMDocument('1.0', 'utf-8');
    $dom->loadXML(file_get_contents('layout.xml'));
    $out = new DOMDocument('1.0', 'utf-8');
    $out->formatOutput = true;

    function conv($src) {
        GLOBAL $dom;
        GLOBAL $out;

        $layout = $out->createElement('layout');    
        
        $retval = $out->createElement('el');
        $retval->setAttribute('name', $src->getAttribute('name')); 
    
        foreach ($src->attributes as $attrName => $attr) {
            if ($attrName != 'name') {
                $layout->setAttribute($attrName, $attr->value);
            }
        }

        if ($layout->attributes->length > 0) {
            $retval->appendChild($layout);
        }
        
        foreach ($src->childNodes as $el) {
            if ($el->nodeType != XML_ELEMENT_NODE) {
                continue;
            }            

            $el = conv($el);
            $retval->appendChild($el);
        }

        return $retval;
    }

    $outRoot = $out->createElement('els');
    $outRoot->appendChild(conv($dom->getElementsByTagName('layout')->item(0)));
    
    echo $out->saveXML($outRoot);
?>
