// Custom report catcher class
class global_log_catcher extends uvm_report_catcher;
    `uvm_object_utils(global_log_catcher)

    // Associative array to store ID-to-filename mappings
    protected string log_files_map[string];
    // Associative array to store file handles, keyed by ID
    protected int log_file_handles[string];


    function new(string name = "global_log_catcher");
        super.new(name);
    endfunction

    // Method to add a target ID and its corresponding log file
    virtual function void add_log_target(string id, string filename);
        if (log_files_map.exists(id)) begin
            `uvm_warning("LOG_CATCHER", $sformatf("Log target for ID '%s' already exists. Overwriting with file '%s'.", id, filename))
        end
        log_files_map[id] = filename;
    endfunction

    // Open all configured log files
    virtual function void open_log_files();
        string filename;
        int    fh;
        int    existing_fh; // Declare here
        foreach (log_files_map[id]) begin
            filename = log_files_map[id];
            existing_fh = 0; // Initialize here before checking
            // Check if file for this filename is already open (shared file)
            foreach (log_file_handles[existing_id]) begin
                if (log_files_map[existing_id] == filename) begin
                    existing_fh = log_file_handles[existing_id];
                    break;
                end
            end

            if (existing_fh != 0) begin
                log_file_handles[id] = existing_fh; // Share the handle
                `uvm_info("LOG_CATCHER", $sformatf("Sharing log file handle for ID '%s' with file '%s'", id, filename), UVM_DEBUG)
            end else begin
                fh = $fopen(filename, "w");
                if (fh == 0) begin
                    `uvm_error("LOG_CATCHER", $sformatf("Failed to open log file '%s' for ID '%s'.", filename, id))
                end else begin
                    log_file_handles[id] = fh;
                    `uvm_info("LOG_CATCHER", $sformatf("Opened log file '%s' for ID '%s'", filename, id), UVM_MEDIUM)
                end
            end
        end
    endfunction

    // Catch method to filter and log messages
    virtual function action_e catch();
        uvm_severity severity = get_severity();
        string       id       = get_id();
        string       message  = get_message();
        uvm_verbosity verbosity = get_verbosity();

        // 只记录UVM标准API可用字段
        if (severity == UVM_INFO && log_files_map.exists(id)) begin
            if (log_file_handles.exists(id)) begin
                int fh = log_file_handles[id];
                // 日志格式只输出可用字段
                $fdisplay(fh, "[%0t] %s: %s", $time, id, message);
            end else begin
                `uvm_warning("LOG_CATCHER", $sformatf("Log file handle not found for configured ID '%s'. Message not logged to file.", id))
            end
        end

        // 允许其他消息默认处理
        return THROW;
    endfunction

    // Close all opened files
    virtual function void close_log_files();
        // Queue to keep track of closed file handles to avoid double closing
        int closed_handles[$];

        // Clear the closed handles queue
        closed_handles.delete();

        foreach (log_file_handles[id]) begin
            int fh = log_file_handles[id];
            bit already_closed = 0;
            foreach(closed_handles[i]) begin
                if (closed_handles[i] == fh) begin
                    already_closed = 1;
                    break;
                end
            end

            if (fh != 0 && !already_closed) begin
                `uvm_info("LOG_CATCHER", $sformatf("Closing log file for ID '%s' (handle %0d)", id, fh), UVM_MEDIUM)
                $fclose(fh);
                closed_handles.push_back(fh);
            end
        end
        log_file_handles.delete(); // Clear the handles map
    endfunction

endclass
