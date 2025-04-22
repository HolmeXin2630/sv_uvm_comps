// Global log component
class global_log_component extends uvm_component;
    `uvm_component_utils(global_log_component)

    global_log_catcher catcher;

    function new(string name = "global_log_component", uvm_component parent = null);
        super.new(name, parent);
        catcher = global_log_catcher::type_id::create("catcher");
    endfunction

    virtual function void add_log_target(string id, string filename);
        this.catch.add_log_target(id, filename);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        catcher = global_log_catcher::type_id::create("catcher");

        // Configure the catcher with ID-to-filename mappings
        // Example configuration:
        catcher.add_log_target("REG_WRITE", "core_activity.log");
        //catcher.add_log_target("REG_READ", "core_activity.log"); // Log to the same file

        // Open the configured log files
        catcher.open_log_files();

        // Register the catcher globally
        uvm_report_cb::add(null, catcher);
        `uvm_info("LOG_COMP", "Global log catcher registered with multiple targets", UVM_LOW)
    endfunction

    // Close files in final phase
    function void final_phase(uvm_phase phase);
        super.final_phase(phase);
        if (catcher != null) begin
            `uvm_info("LOG_COMP", "Closing log files in final_phase", UVM_LOW)
            catcher.close_log_files();
        end
    endfunction

endclass
