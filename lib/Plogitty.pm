# ABSTRACT: A Static Website Generator
package Plogitty;
use oCLI qw( oCLI::Plugin::Validate Plogitty::Plugin::CommandRouter );
extends qw( oCLI );

__PACKAGE__->model(
    'Markdown' => {
        class => 'Plogitty::Model::Markdown',
        args  => { },
    },
);

__PACKAGE__->model(
    'Xslate' => {
        class => 'Text::Xslate',
        args  => { 
            syntax    => 'Metakolon',
            cache_dir => './.xslate_cache',
            path      => [ 'template' ],
        },
    },
);


1;
