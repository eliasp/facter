#! /usr/bin/env ruby

require 'spec_helper'
require 'facter/util/ip'


def ifconfig_fixture(filename)
  File.read(fixtures('ifconfig', filename))
end

describe "macaddress fact" do
  include FacterSpec::ConfigHelper

  before do
    given_a_configuration_of(:is_windows => false)
  end

  describe "when run on Linux" do
    describe "with /sys available" do
      before :each do
        Facter.fact(:kernel).stubs(:value).returns("Linux")
        Facter.fact(:operatingsystem).stubs(:value).returns("Linux")
        File.stubs(:exist?).with('/sys/class/net/').returns(true)
        File.stubs(:read).with('/sys/class/net/eth0/address').returns( "00:12:3f:be:22:01\n" )
        File.stubs(:read).with('/sys/class/net/ip6tnl0/address').returns( "00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00\n" )
        File.stubs(:read).with('/sys/class/net/lo/address').returns( "00:00:00:00:00:00\n" )
        File.stubs(:read).with('/sys/class/net/sit0/address').returns( "00:00:00:00\n" )
      end

      it "should get netdevice directory entries in /sys/class/net/" do
        Dir.stubs(:entries).with('/sys/class/net/').returns( ['/sys/class/net/eth0', '/sys/class/net/lo'] )

        File.expects(:entries).with('/sys/class/net/').should == ['/sys/class/net/eth0', '/sys/class/net/lo']
      end

      it "should read /sys/class/net/eth0/address" do
        Facter.fact(:macaddress).value.should == "00:12:3f:be:22:01"
      end

      describe "and only invalid interfaces available" do
        before :each do
          #Dir.expects(:glob).with('/sys/class/net/*').returns(['/sys/class/net/ip6tnl0', '/sys/class/net/lo', '/sys/class/net/sit0'])
        end

        it "should not return any mac address" do
        end
      end
    end
    describe "without /sys available" do
      before :each do
        Facter.fact(:kernel).stubs(:value).returns("Linux")
        Facter.fact(:operatingsystem).stubs(:value).returns("Linux")
        Facter::Util::IP.stubs(:get_ifconfig).returns("/sbin/ifconfig")
        Dir.stubs(:glob).with('/sys/class/net/*').returns([])
      end

      it "should return the macaddress of the first interface" do
        Facter::Util::IP.stubs(:exec_ifconfig).with(["-a","2>/dev/null"]).
          returns(ifconfig_fixture('linux_ifconfig_all_with_multiple_interfaces'))

        Facter.value(:macaddress).should == "00:12:3f:be:22:01"
      end

      it "should return nil when no macaddress can be found" do
        Facter::Util::IP.stubs(:exec_ifconfig).with(["-a","2>/dev/null"]).
          returns(ifconfig_fixture('linux_ifconfig_no_mac'))

        expect { Facter.value(:macaddress) }.to_not raise_error
        Facter.value(:macaddress).should be_nil
      end

      # some interfaces dont have a real mac addresses (like venet inside a container)
      it "should return nil when no interface has a real macaddress" do
        Facter::Util::IP.stubs(:exec_ifconfig).with(["-a","2>/dev/null"]).
          returns(ifconfig_fixture('linux_ifconfig_venet'))

        expect { Facter.value(:macaddress) }.to_not raise_error
        Facter.value(:macaddress).should be_nil
      end
    end
  end

  describe "when run on BSD" do
    it "should return macaddress information" do
      Facter.fact(:kernel).stubs(:value).returns("FreeBSD")
      Facter::Util::IP.stubs(:get_ifconfig).returns("/sbin/ifconfig")
      Facter::Util::IP.stubs(:exec_ifconfig).
        returns(ifconfig_fixture('bsd_ifconfig_all_with_multiple_interfaces'))

      Facter.value(:macaddress).should == "00:0b:db:93:09:67"
    end
  end

  describe "when run on OpenBSD with bridge(4) rules" do
    it "should return macaddress information" do
      Facter.fact(:kernel).stubs(:value).returns("OpenBSD")
      Facter::Util::IP.stubs(:get_ifconfig).returns("/sbin/ifconfig")
      Facter::Util::IP.stubs(:exec_ifconfig).
        returns(ifconfig_fixture('openbsd_bridge_rules'))

      expect { Facter.value(:macaddress) }.to_not raise_error
      Facter.value(:macaddress).should be_nil
    end
  end

end
