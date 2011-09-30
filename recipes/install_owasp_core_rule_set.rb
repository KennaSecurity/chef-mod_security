
package "unzip" do
  action :install
end

directory "#{node[:mod_security][:crs][:rules_root_dir]}" do
  recursive true
end
directory "#{node[:mod_security][:crs][:files]}" do
  recursive true
end

# install zipfile
zipfile = "#{node[:mod_security][:crs][:files]}/modsecurity-crs_#{node[:mod_security][:crs][:version]}.zip"
cookbook_file zipfile do
  action :create_if_missing
  mode   "0644"
  backup false
end

# unzip core rule set if zipfile is updated
execute "unzip_core_rule_set" do
  command "unzip -q #{zipfile} -d #{node[:mod_security][:crs][:rules_root_dir]}"
  action :nothing
  subscribes :run, resources(:cookbook_file => zipfile), :immediately
end

# install settings config
# - currently heavily tied to version of crs. be wary of updating one
# - without the other
template "#{node[:mod_security][:crs][:rules_root_dir]}/modsecurity_crs_10_config.conf" do
  mode "0644"
  notifies :restart, resources(:service => "apache2"), :delayed
end

node[:mod_security][:crs][:rules].each_pair do |rule_group,rules|
  rule_dir = "#{node[:mod_security][:crs][:rules_root_dir]}/#{rule_group}_rules"
  rules.each_pair do |rule,flag|
    link "#{node[:mod_security][:crs][:activated_rules]}/#{rule}.conf" do
      to "#{rule_dir}/#{rule}.conf"
      action (flag ? :create : :delete )
      notifies :restart, resources(:service => "apache2"), :delayed
    end

    # why does the crs disappear from the data filenames? why!?
    data_filename = "#{rule.gsub(/crs_/,'')}.data"
    # other data filename anomalies
    
    link "#{node[:mod_security][:crs][:activated_rules]}/#{data_filename}" do
      to "#{rule_dir}/#{data_filename}"
      action (flag ? :create : :delete )
      only_if "test -e #{rule_dir}/#{data_filename}"
      notifies :restart, resources(:service => "apache2"), :delayed
    end
    
  end
end 
