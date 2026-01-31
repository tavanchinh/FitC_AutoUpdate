// 1. Hàm nhận dữ liệu từ Ruby khi mở bảng
function updateFields(data) {
    console.log("Dữ liệu nhận từ Ruby:", data);
    if (!data) return;
    document.getElementById('min_size').value = data.min_size || 100;
    document.getElementById('layer_left').value = data.layer_left || 'TRAI';
    document.getElementById('color_left').value = data.color_left || '#FF0000';
    document.getElementById('layer_right').value = data.layer_right || 'PHAI';
    document.getElementById('color_right').value = data.color_right || '#0000FF';
}

// 2. Hàm thu thập dữ liệu và gửi ngược về Ruby (Thay cho sendDataToRuby)
function collectAndSend() {
    const data = {
        min_size: parseFloat(document.getElementById('min_size').value),
        max_count: document.getElementById('max_count').value,
        layer_left: document.getElementById('layer_left').value,
        color_left: document.getElementById('color_left').value,
        layer_right: document.getElementById('layer_right').value,
        color_right: document.getElementById('color_right').value
    };

    console.log("Đang gửi dữ liệu về Ruby:", data);

    // Gọi callback 'run_process' đã định nghĩa trong Ruby
    if (window.sketchup && window.sketchup.run_process) {
        sketchup.run_process(data);
    } else {
        alert("Lỗi: Không tìm thấy kết nối SketchUp!");
    }
}

// 3. Báo cho Ruby là JS đã sẵn sàng để nhận dữ liệu
document.addEventListener('DOMContentLoaded', () => {
    if (window.sketchup && window.sketchup.ready) {
        sketchup.ready();
    }
});