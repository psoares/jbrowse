=head1 NAME

Bio::JBrowse::libs - when included, sets JBrowse Perl module paths,
optimized for running directly from the JBrowse dir

=cut

package Bio::JBrowse::libs;

if( -e 'extlib' ) {
    require lib;
    lib->import( 'extlib/lib/perl5' );
    require local::lib;
    local::lib->import( 'extlib' );
}

1;
