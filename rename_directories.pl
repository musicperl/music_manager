#!/usr/bin/perl

# TODO: track numbers
      

# TODO: in some corner case, you could overwrite
# TODO: odd characters
# TODO: skip tribute and various artists?

# Make database from metal archives for all ids in ids database
use File::Glob ':bsd_glob';
use MP3::Tag;
use strict;
use warnings;
use Path::Class;
use autodie; # die if problem reading or writing a file
use List::MoreUtils qw(uniq);
use Cwd;
use constant {
    MP3   => 1,
    FLAC   => 2,
    NONE => 0,
};

sub error{
  my ($msg) = @_;
  print("ERROR: " . $msg);
  #exit(0);
}

sub checkBadFiles{
  my ($todir, $dirh, $ext) = @_;
  my @files_m3u = map{"$todir/$_"}grep(/\.$ext$/, readdir($dirh));
  if( scalar(@files_m3u) > 0 ){
    error("$ext files in $todir\n");
  }
}

sub myreaddir{
  my ($this_dirh) = @_;
  my @files = readdir($this_dirh); 
  @files = grep { $_ ne '.' && $_ ne '..'} @files;
  return @files;
}

sub rename_album_dirs{
  my ($this_dir, $depth, $file_type) = @_;

  # Set expected file type
  if( index($this_dir, "[FLAC]") != -1 ){
    if( $file_type != NONE ){
      error("Error: $this_dir has [FLAC] but expected mp3. Assumed that at depth $depth > 2 => all subdirectories contain mp3s.\n");
    }
    $file_type = FLAC;
  }elsif( $depth > 1 ){
    if( $file_type == FLAC ){
      error("Error FLAC -> mp3?\n");
    }
    $file_type = MP3;
  }
  opendir my($this_dirh), $this_dir or die "Could not open $this_dir!\n";

  my @files = myreaddir($this_dirh); 
  @files = map{"$this_dir/$_"} @files;
  my @files_mp3 = grep(/\.[mM][pP]3$/, @files);
  my @files_flac = grep(/\.[fF][lL][aA][cC]$/, @files);

  #my @exts = uniq map{$_ =~ /(\.[^.]+)$/} @files;
  #print("Extensions: " . join(", ", @exts));
  #my ($ext) = $file =~ /(\.[^.]+)$/;

  # Check for no weird file extensions
  #checkBadFiles($this_dir, $dirh, "m3u");
  #checkBadFiles($this_dir, $dirh, "nfo");
  closedir $this_dirh;

  # check that directory ends in [FLAC] iff it has flac files
  if( scalar(@files_flac) > 0 && $file_type == MP3 ){
    error("$this_dir has files with type FLAC!\n");
  }elsif( scalar( @files_mp3) > 0 && $file_type == FLAC ){
    error("$this_dir has files with type mp3!\n");
  }
  # 

  if( scalar(@files_mp3) > 0 && scalar(@files_flac) > 0 ){
    error("TODO: fix this\n");
  }

  #print(join("\n", @files_mp3));
  my $album = undef;
  my $year = undef;
  if( $file_type == MP3 ){
    foreach my $file_mp3(@files_mp3){
      if( $depth == 0 ){
        error("MP3 file $file_mp3 at depth $depth in $this_dir!\n");
      }
      #print("MP3 file: $file_mp3\n");
      my $mp3 = MP3::Tag->new($file_mp3);
      $mp3->get_tags();
      if( exists $mp3->{ID3v1}){
        my $current_album = $mp3->{ID3v1}->album;
        my $current_track = $mp3->{ID3v1}->track;
        my $current_year = $mp3->{ID3v1}->year;
        if( $current_track eq '' || !defined $current_track ){
          error("$file_mp3 has no track!\n");
        }

        if( ! defined $album ){
          $album = $current_album;
          $year = $current_year;
        }elsif( $album ne $current_album ){
          error("Multiple albums per directory in $this_dir: $album, $current_album!\n");
        }elsif( $year ne $current_year ){
          error("Multiple years per directory in $this_dir: $year, $current_year!\n");
        }
      }else{
        error("not ID3V1: $file_mp3!\n");
      }
    }
  }elsif( $file_type == FLAC ){
    #print("Skipping directory with FLAC files for now: $this_dir\n");
    return;
  }

  if( defined $album ){
    #print("$this_dir -> $album ($year)\n");
  }

  # Recurse
  foreach my $file(@files){
    #if(length($file) > 1 && substr($file, 0, 1) eq '.' ){
    if( $file eq './.' || $file eq '.' || $file eq '..' || $file eq './..'){
      next;
    }
    if( -d $file ){
      # TODO: ends with
      my $next_depth = (substr($file, -length("Listened (Music)")) eq "Listened (Music)" || 
                        substr($file, -length("Listened (Lossy)")) eq "Listened (Lossy)") ? $depth : $depth + 1;
      rename_album_dirs($file, $next_depth, $file_type);
    }
  } # end file loop
} # end function rename_album_dirs

rename_album_dirs('.', 0, NONE);


