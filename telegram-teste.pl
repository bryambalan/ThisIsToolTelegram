#!/usr/bin/perl

# Envio de gráfico por email através do ZABBIX (Send zabbix alerts graph mail)
#
# 
# Copyright (C) <2016>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

use strict;
use warnings;
use Data::Dumper;
use HTTP::Cookies;
use WWW::Mechanize; 
use JSON::RPC::Client;
use Encode;
use POSIX;

## Dados do Zabbix ##############################################################################################################
my $server_ip  = 'http://127.0.0.1/zabbix'; # URL de acesso ao FRONT com "http://"
my $user       = 'Admin';
my $password   = 'zabbix';
my $script     = '/etc/zabbix/scripts/telegram';
my $client     = new JSON::RPC::Client;
my ($json, $response, $authID);
#################################################################################################################################

## Configuracao do Grafico ######################################################################################################
my $color   = '00C800'; # Cor do grafico em Hex. (sem tralha)
my $period  = 3600; # 1 hora em segundos
my $height  = 200;  # Altura
my $width   = 900;  # Largura   
my $stime   = strftime("%Y%m%d%H%M%S", localtime( time-3600 )); # Hora inicial do grafico [time-3600 = 1 hora atras]         
#################################################################################################################################

## Configuracao do Grafico ######################################################################################################
my $itemid     = '23316';
my $subject    = 'ALARME';
my $itemname   = 'MEMORIA DISPONIVEL';
my $body       = 'Teste de envio';
#################################################################################################################################
unless ($itemid){
                print "<<< Item inválido ou USER do front sem permissão de leitura no host >>>\n";
                exit;
}

my $graph = "/tmp/$itemid.png";

my $mech = WWW::Mechanize->new();
$mech->cookie_jar(HTTP::Cookies->new());
$mech->get("$server_ip/index.php?login=1");
$mech->field(name => $user);
$mech->field(password => $password);
$mech->click();

my $png = $mech->get("$server_ip/chart3.php?name=$itemname&period=$period&width=$width&height=$height&stime=$stime&items[0][itemid]=$itemid&items[0][drawtype]=5&items[0][color]=$color");

open my $image, '>', $graph or die $!;
$image->print($png->decoded_content);
$image->close;
#################################################################################################################################

## Bom dia, boa tarde ou boa noite ##############################################################################################
my $hour = strftime '%H', localtime;
my $salutation;
if ($hour < "12")
{
	$salutation = "Bom dia"; #Good Morning
}
elsif ($hour >= "18")
{
	$salutation = "Boa noite"; #Good Night
}
else
{
	$salutation = "Boa tarde"; #Good Afternoon
}
#################################################################################################################################

utf8::decode($subject);
utf8::decode($body);

chop($script) while ($script =~ m/^.*\/$/);

chdir($script); #|| die "Não foi possivel localizar o diretório do telegram-cli:$!";
        unless (chdir($script)){
        print "<<< Pasta do telegram-cli declarada errada >>>\n";
        exit;
       }
if (&tipo == 0 || &tipo == 3) {
				`./telegram-cli -k tg-server.pub -c telegram.config -WR -U zabbix -e 'send_photo $ARGV[0] $graph "$salutation $ARGV[0] \\n\\n$subject $body"'` || die "Não foi possivel executar o telegram-cli:$!";
}
else {
	`./telegram-cli -k tg-server.pub -c telegram.config -WR -U zabbix -e 'msg $ARGV[0] "$salutation $ARGV[0] \\n\\n$subject $body"'` || die "Não foi possivel executar o telegram-cli:$!";
}

unlink ("$graph");

sub tipo {
	$json = {
		jsonrpc => '2.0',
		method  => 'user.login',
		params  => {
			user  => $user  ,
			password => $password
     		},
   		id => 1
  	};

	$response = $client->call("$server_ip/api_jsonrpc.php", $json);
	#print Dumper ($response);
	unless ($response){
    print "<<< URL declarada para o front errada >>>\n";
    exit;
    }
        unless ($response->content->{'result'}){
        print "<<< Usuário ou senha inválido >>>\n";
        exit;
        }	
		
	$authID = $response->content->{'result'};
	$itemid =~ s/^\s+//;

	$json = {
		jsonrpc => '2.0',
	   	method  => 'item.get',
		params  => {
			output => ['value_type'],
			itemids => $itemid,
			webitems => $itemid
     		},
   		auth => $authID,
		id => 2
  	};
	$response = $client->call("$server_ip/api_jsonrpc.php", $json);
	#print Dumper ($response);
	
        my $itemtype;
        foreach my $get_itemtype (@{$response->content->{result}}) {
                $itemtype = $get_itemtype->{value_type}
        }
        unless (defined $itemtype){
                print "<<< Item inválido ou USER do front sem permissão de leitura no host >>>\n";
                exit;
        }

        return $itemtype;
}

exit;
