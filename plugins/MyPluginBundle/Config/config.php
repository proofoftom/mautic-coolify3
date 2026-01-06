<?php

return [
    'name'        => 'My Plugin',
    'description' => 'Example custom plugin for Mautic',
    'version'     => '1.0.0',
    'author'      => 'Your Name',
    'services'    => [
        'events' => [
            'mautic.myplugin.subscriber' => [
                'class' => 'Mautic\PluginBundle\EventListener\MyPluginSubscriber',
            ],
        ],
    ],
];
