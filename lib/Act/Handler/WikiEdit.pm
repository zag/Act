package Act::Handler::WikiEdit;

use strict;
use Apache::Constants qw(NOT_FOUND FORBIDDEN);

use Act::Config;
use Act::Template::HTML;
use Act::Util;
use Act::Wiki;

my %actions = (
    commit  => \&wiki_commit,
    edit    => \&wiki_edit,
    revert  => \&wiki_revert,
);

sub handler
{
    my $action = $Request{args}{action};
    unless (exists $actions{$action}) {
        $Request{status} = NOT_FOUND;
        return;
    }
    my $wiki = Act::Wiki->new();
    my $template = Act::Template::HTML->new();
    $actions{$action}->($wiki, $template);
}
sub wiki_edit
{
    my ($wiki, $template) = @_;

    my $node = $Request{args}{node};
    unless ($node) {
        $Request{status} = NOT_FOUND;
        return;
    }
    my %data = $wiki->retrieve_node(name => Act::Wiki::make_node_name($node));
    $template->variables(
        node     => $node,
        content  => $data{content},
        checksum => $data{checksum},
    );
    $template->process('wiki/edit');
}
sub wiki_commit
{
    my ($wiki, $template) = @_;

    my $node = $Request{args}{node};
    unless ($node) {
        $Request{status} = NOT_FOUND;
        return;
    }
    # preview
    if ($Request{args}{preview}) {
        $template->variables_raw(
            preview_content => Act::Wiki::format_node($wiki, $template, $Request{args}{content}),
            content         => $Request{args}{content},
        );
        $template->variables(
            preview  => 1,
            node     => $node,
            checksum => $Request{args}{checksum},
        );
        $template->process('wiki/edit');
        return;
    }
    # store the node
    my $name = Act::Wiki::make_node_name($node);
    if ($wiki->write_node(
        $name,
        $Request{args}{content},
        $Request{args}{checksum},
        { # metadata
         user_id => $Request{user}->user_id,
        }
       ))
    {
        # display the node again
        Act::Wiki::display_node($wiki, $template, $node);
    }
    else {
        # conflict
        my %data = $wiki->retrieve_node(name => $name);
        $template->variables(
            conflict    => 1,
            node        => $node,
            new_content => $Request{args}{content},
            content     => $data{content},
            checksum    => $data{checksum},
        );
        $template->process('wiki/edit');
    }
}
sub wiki_revert
{
    my ($wiki, $template) = @_;

    unless ($Request{user}->is_orga) {
        $Request{status} = FORBIDDEN;
        return;
    }
    my ($node, $version) = map $Request{args}{$_}, qw(node version);
    unless ($node && $version) {
        $Request{status} = NOT_FOUND;
        return;
    }
    # retrieve checksum of latest version
    my $name = Act::Wiki::make_node_name($node);
    my %node = $wiki->retrieve_node(name => $name);
    my $checksum = $node{checksum};

    # retrieve version to revert to
    %node = $wiki->retrieve_node(name => $name, version => $version);

    # revert
    $wiki->write_node($name, $node{content}, $checksum,
                  {
                   user_id => $Request{user}->user_id,
                  }
                );

    # display the node again
    Act::Wiki::display_node($wiki, $template, $node);
}
1;
__END__

=head1 NAME

Act::Handler::WikiEdit - modify wiki pages

=head1 DESCRIPTION

See F<DEVDOC> for a complete discussion on handlers.

=cut
