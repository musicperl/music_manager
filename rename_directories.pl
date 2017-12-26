#!/usr/bin/perl
#
#F:\Perl\bin\perl
# Make database from metal archives for all ids in ids database
use File::Glob ':bsd_glob';
use MP3::Tag;
#use Tie::Array;	
use strict;
use warnings;
use Path::Class;
use autodie; # die if problem reading or writing a file
use List::MoreUtils qw(uniq);
use Cwd;

my ($sec,$min,$hour,$mday,$mon,$current_year,$wday,$yday,$isdst) = localtime();
$current_year = $current_year+1900;

# TODO: pass the level and make sure that the level is correct
sub checkBadFiles{
  my ($todir, $dirh, $ext) = @_;
  my @files_m3u = map{"$todir/$_"}grep(/\.$ext$/, readdir($dirh));
  if( scalar(@files_m3u) > 0 ){
    print("ERROR: $ext files in $todir\n");
    exit(0);
  }
}

sub myreaddir{
  my ($thisdirh) = @_;
  my @files = readdir($thisdirh); 
  @files = grep { $_ ne '.' && $_ ne '..'} @files;
  return @files;
}

sub rename_album_dirs{
  my ($thisdir, $depth) = @_;
  opendir my($thisdirh), $thisdir or die "Could not open $thisdir!\n";

  my @files = myreaddir($thisdirh); 
  @files = map{"$thisdir/$_"} @files;

  #my @files = glob("$thisdir/*");
  #my @files = glob "\"$thisdir/*\"";
  print("files: \n");
  foreach my $file(@files){
    if($file eq './.' || $file eq '.' || $file eq '..' || $file eq './..'){
      next;
    }
    print($file . "\n");
  }
  #exit(0);

  foreach my $file(@files){
    if($file eq './.' || $file eq '.' || $file eq '..' || $file eq './..'){
      next;
    }
    my $todir = $file; #$thisdir . "/" . $file;
    #print( "todir: $todir\n");
    if( -d $todir ){
      opendir my($dirh), $todir or die "Could not open $todir!\n";
      my @files = map{"$todir/$_"} myreaddir($dirh);
      my @files_mp3 = grep(/\.[mM][pP]3$/, @files);
      #my @files_flac = grep(/\.flac$/, @files);
      my @files_flac = grep(/\.[fF][lL][aA][cC]$/, @files);
      #my @exts = uniq map{$_ =~ /(\.[^.]+)$/} @files;
      #print("Extensions: " . join(", ", @exts));
      #my ($ext) = $file =~ /(\.[^.]+)$/;

      # Check for no weird file extensions
      #checkBadFiles($todir, $dirh, "m3u");
      #checkBadFiles($todir, $dirh, "nfo");
      closedir $dirh;

      # check that directory ends in [FLAC] iff it has flac files
      if( index($todir, "[FLAC]") != -1 ){
        if( scalar(@files_flac) == 0 ){
          print("$todir has no FLAC files!\n");
          print(join("\n", @files));
          exit(0);
        }
      }else{
        if( scalar(@files_flac) > 0 ){
          print("$todir has FLAC files!\n");
          exit(0);
        }
      }
      # 
      if( scalar(@files_flac) > 1 ){
        print("Skipping directory with FLAC files: $todir\n");
        next;
      }

      #print(join("\n", @files_mp3));
      # TODO: FLAC
      my $album = undef;
      my $year = undef;
      foreach my $file_mp3(@files_mp3){
        if( $depth != 1 ){
          print("ERROR: Mp3 file $file_mp3 at depth $depth in $todir!\n");

          exit(0);
        }
        #print("MP3 file: $file_mp3\n");
        my $mp3 = MP3::Tag->new($file_mp3);
        $mp3->get_tags();
        if( exists $mp3->{ID3v1}){
          my $current_album = $mp3->{ID3v1}->album;
          my $current_year = $mp3->{ID3v1}->year;

          if( ! defined $album ){
            $album = $current_album;
            $year = $current_year;
          }elsif( $album ne $current_album ){
            print("Multiple albums per directory in $todir!\n");
            exit(0);
          }elsif( $year ne $current_year ){
            print("Multiple years per directory in $todir!\n");
            exit(0);
          }
        }else{
          print("not ID3V1: $file_mp3!\n");
          exit(0);
        }
      }
      if( defined $album ){
        print("$todir -> $album\n");
      }else{
        if( $depth == 1 ){
        #print("glob \"$todir/*.mp3\"\n");
          print(sprintf("WARNING: Do not rename: $todir (%d mp3s)\n", scalar(@files_mp3)));
        }
        rename_album_dirs($todir, $depth+1);
      }
    }
  } # end file loop
} # end function rename_album_dirs

rename_album_dirs('.', 0);


