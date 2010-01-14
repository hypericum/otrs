# --
# Kernel/Output/HTML/DashboardRSS.pm
# Copyright (C) 2001-2010 OTRS AG, http://otrs.org/
# --
# $Id: DashboardRSS.pm,v 1.12.2.2 2010-01-14 14:20:59 mb Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::DashboardRSS;

use strict;
use warnings;

use XML::FeedPP;

use vars qw($VERSION);
$VERSION = qw($Revision: 1.12.2.2 $) [1];

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # get needed objects
    for (
        qw(Config Name ConfigObject LogObject DBObject LayoutObject ParamObject TicketObject UserID)
        )
    {
        die "Got no $_!" if ( !$Self->{$_} );
    }

    return $Self;
}

sub Preferences {
    my ( $Self, %Param ) = @_;

    return;
}

sub Config {
    my ( $Self, %Param ) = @_;

    return (
        %{ $Self->{Config} },
        CacheKey => 'RSS' . $Self->{Config}->{URL} . '-' . $Self->{LayoutObject}->{UserLanguage},
    );
}

sub Run {
    my ( $Self, %Param ) = @_;

    # set proxy settings can't use Kernel::System::WebAgent because of used
    # XML::FeedPP to get RSS files
    my $Proxy = $Self->{ConfigObject}->Get('WebUserAgent::Proxy');
    if ($Proxy) {
        $ENV{CGI_HTTP_PROXY} = $Proxy;
    }

    # get content
    my %Options;
    if ( $Self->{EncodeObject}->EncodeInternalUsed() ) {
        $Options{utf8_flag} = 1;
    }
    my $Feed = eval { XML::FeedPP->new( $Self->{Config}->{URL}, %Options ) };

    if ( !$Feed ) {
        my $Content = "Can't connect to " . $Self->{Config}->{URL};
        return $Content;
    }

    my $Count = 0;
    for my $Item ( $Feed->get_item() ) {
        $Count++;
        last if $Count > $Self->{Config}->{Limit};
        my $Time = $Item->pubDate();
        my $Ago  = '-';
        if ($Time) {
            my $SystemTime = $Self->{TimeObject}->TimeStamp2SystemTime(
                String => $Time,
            );
            $Ago = $Self->{TimeObject}->SystemTime() - $SystemTime;
            $Ago = $Self->{LayoutObject}->CustomerAge(
                Age   => $Ago,
                Space => ' ',
            );
        }
        my $Title = $Item->title();

        # Feeds are always utf-8, Convert if needed
        if ( $Self->{LayoutObject}->{UserCharset} ne 'utf-8' ) {
            my $Title = $Self->{EncodeObject}->Convert(
                Text => $Title,
                From => 'utf-8',
                To   => $Self->{LayoutObject}->{UserCharset},
            );
        }

        $Self->{LayoutObject}->Block(
            Name => 'ContentSmallRSSOverviewRow',
            Data => {
                Title => $Title,
                Link  => $Item->link(),
                Ago   => $Ago,
            },
        );
    }
    my $Content = $Self->{LayoutObject}->Output(
        TemplateFile => 'AgentDashboardRSSOverview',
        Data         => {
            %{ $Self->{Config} },
        },
    );

    return $Content;
}

1;
